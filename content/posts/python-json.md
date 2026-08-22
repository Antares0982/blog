---
title: "警惕第三方Python JSON库的性能陷阱"
slug: "python-json"
date: 2025-12-28T02:34:17+08:00
lastmod: 2026-03-15T02:02:04+08:00
wpid: 418
wpguid: "https://chr.fan/?p=418"
views: 1755
categories: ["技术"]
tags: ["Python", "JSON", "SIMD", "orjson", "ssrJSON", "msgspec", "ujson"]
---

[orjson](https://github.com/ijl/orjson/blob/3.11.3/README.md#:~:text=It%20benchmarks%20as%20the%20fastest)自称其是世界上性能最高的Python JSON库，根据其README中的说法，其dumps速度能达到标准库json的10倍，loads是json的2倍。

我们来生成一个非常简单的纯中文测试用例，来看看orjson（v3.11.3）的实际性能和内存占用的表现如何。先看看`dumps`：

```python
import gc
import json
import time

import orjson
import psutil

process = psutil.Process()


def get_obj():
    d = {}
    for i in range(16):
        k = "中" * (2**i)
        v = "文" * (2 ** (i + 1))
        d[k] = v
    return d


def do_test(test_cases, func):
    t0 = time.perf_counter()
    for case in test_cases:
        func(case)
    t1 = time.perf_counter()
    return t1 - t0


def test_dumps(func):
    test_cases = [get_obj() for _ in range(1000)]
    gc.collect()
    memory_before = process.memory_info().rss
    ret = do_test(test_cases, func)
    gc.collect()
    memory_after = process.memory_info().rss
    memory_increase = (memory_after - memory_before) / 1024 / 1024
    return ret, memory_increase


json_time, json_mem_inc = test_dumps(json.dumps)
orjson_time, orjson_mem_inc = test_dumps(orjson.dumps)

print(
    f"json.dumps: {json_time:.4f} seconds,",
    f"memory increase: {json_mem_inc:.2f} MB",
)
print(
    f"orjson.dumps: {orjson_time:.4f} seconds,",
    f"memory increase: {orjson_mem_inc:.2f} MB",
)
print("orjson is {:.3f}x faster than json".format(json_time / orjson_time))
```

测试环境为Linux, NixOS, Intel i13700k，Python 3.14.0 输出结果如下

```python
json.dumps: 0.9129 seconds, memory increase: 1.32 MB
orjson.dumps: 0.3421 seconds, memory increase: 565.32 MB
orjson is 2.669x faster than json
```

看起来只有其宣传的10倍的四分之一左右的性能，并且产生了565MB左右无法gc的内存占用。

接下来再看看`loads`：

```python
import gc
import json
import time

import orjson
import psutil

process = psutil.Process()

def get_str():
    parts = []
    for i in range(16):
        k = "中" * (2**i)
        v = "文" * (2 ** (i + 1))
        parts.append(f'"{k}":"{v}"')
    return "{" + ",".join(parts) + "}"


def do_test(test_cases, func):
    t0 = time.perf_counter()
    for case in test_cases:
        func(case)
    t1 = time.perf_counter()
    return t1 - t0


def test_loads(func):
    test_cases = [get_str() for _ in range(1000)]
    gc.collect()
    memory_before = process.memory_info().rss
    ret = do_test(test_cases, func)
    gc.collect()
    memory_after = process.memory_info().rss
    memory_increase = (memory_after - memory_before) / 1024 / 1024
    return ret, memory_increase


json_time, json_mem_inc = test_loads(json.loads)
orjson_time, orjson_mem_inc = test_loads(orjson.loads)

print(
    f"json.loads: {json_time:.4f} seconds,",
    f"memory increase: {json_mem_inc:.2f} MB",
)
print(
    f"orjson.loads: {orjson_time:.4f} seconds,",
    f"memory increase: {orjson_mem_inc:.2f} MB",
)
print("orjson is {:.3f}x slower than json!".format(orjson_time / json_time))
```

Python 3.14.0 输出结果如下：

```
json.loads: 0.2312 seconds, memory increase: 0.00 MB
orjson.loads: 0.4873 seconds, memory increase: 562.89 MB
orjson is 2.108x slower than json!
```

也就是说，比标准库json慢了两倍多，内存还多出了562MB无法gc的部分……

除了orjson以外，再看看[msgspec](https://github.com/jcrist/msgspec)(v0.19.0), [ujson](https://github.com/ultrajson/ultrajson)(v5.10.0)这两个同样非常流行的JSON库。用上面同样的代码改一改测试的函数

```diff
-orjson_time, orjson_mem_inc = test_dumps(orjson.dumps)
+# msgspec_time, msgspec_mem_inc = test_dumps(msgspec.json.encode)  # msgspec encode
+# ujson_time, ujson_mem_inc = test_dumps(ujson.dumps)  # ujson dumps
```

```diff
-orjson_time, orjson_mem_inc = test_loads(orjson.loads)
+# msgspec_time, msgspec_mem_inc = test_dumps(msgspec.json.decode)  # msgspec decode
+# ujson_time, ujson_mem_inc = test_dumps(ujson.loads)  # ujson loads
```

在同一台设备上可以测得

```
json.dumps: 0.9273 seconds, memory increase: 1.32 MB
msgspec.json.encode: 0.4336 seconds, memory increase: 565.71 MB
msgspec is 2.139x faster than json
```

```
json.dumps: 0.9361 seconds, memory increase: 1.32 MB
ujson.dumps: 0.5560 seconds, memory increase: 2.40 MB
ujson is 1.684x faster than json
```

```
json.loads: 0.2353 seconds, memory increase: 0.00 MB
msgspec.json.decode: 0.7281 seconds, memory increase: 566.47 MB
msgspec is 3.094x slower than json!
```

```
json.loads: 0.2362 seconds, memory increase: 0.00 MB
ujson.loads: 0.3609 seconds, memory increase: 3.27 MB
ujson is 1.528x slower than json!
```

到底发生了什么？使用第三方JSON库，需要注意哪些坑点？

让我们带着这些疑问，深入CPython和各个三方库的实现内部，探索JSON编解码的最佳实践。

## PyUnicode

在一切的讨论成立之前，我们有必要先详细了解一下CPython中的`str`类型的实现。Python中的`str`对象，在CPython中对应的结构体是`PyUnicodeObject`（后文简称PyUnicode），这一对象中存储的是字符串中各个字符的unicode point。以下为 CPython 3.14.0 的[源码](https://github.com/python/cpython/blob/v3.14.0/Include/cpython/unicodeobject.h)，删除一些太长的注释之后如下

```c
typedef struct {
    PyObject_HEAD
    Py_ssize_t length;          /* Number of code points in the string */
    Py_hash_t hash;             /* Hash value; -1 if not set */
#ifdef Py_GIL_DISABLED
   _Py_ALIGN_AS(4)
#endif
    struct {
#ifdef Py_GIL_DISABLED
        unsigned char interned;
#else
        unsigned int interned:2;
#endif
        unsigned int kind:3;
        unsigned int compact:1;
        unsigned int ascii:1;
        unsigned int statically_allocated:1;
#ifndef Py_GIL_DISABLED
        unsigned int :24;
#endif
    } state;
} PyASCIIObject;

typedef struct {
    PyASCIIObject _base;
    Py_ssize_t utf8_length;     /* Number of bytes in utf8, excluding the
                                 * terminating \0. */
    char *utf8;                 /* UTF-8 representation (null-terminated) */
} PyCompactUnicodeObject;

typedef struct {
    PyCompactUnicodeObject _base;
    union {
        void *any;
        Py_UCS1 *latin1;
        Py_UCS2 *ucs2;
        Py_UCS4 *ucs4;
    } data;                     /* Canonical, smallest-form Unicode buffer */
} PyUnicodeObject;
```

根据这一内存布局，在运行时，一个`PyUnicodeObject*`指针对应的内存，同样可以被翻译为`PyASCIIObject`或`PyCompactUnicodeObject`。unicode的个数，也就是字符串长度，记录在`PyASCIIObject`的`length`中。一个字符串对象，其状态被`PyASCIIObject`结构体中的`state`描述，其中一些（位域）字段是本文中我们不用关心的：

* `interned`：用来提示CPython在清理阶段如何处理该对象。
* `statically_allocated`：字符串的这段内存是否是静态分配的。
* `compact`：字符串是否是紧凑的，也就是说字符串的实际内容是否和`PyUnicodeObject`在同一个内存块上（尾随结构体之后）。因为CPython的继承机制，`str`的子类对象需要在`PyUnicodeObject`结构体后定义其自身的属性，因此不会是compact的。但本文中我们只关心`str`对象，不关心子类的情况，因此接下来的讨论中假设该值始终为1。

一个`PyUnicodeObject`根据其内部的unicode数据不同，会表现出4种不同的存储形式。

* 当所有字符的unicode point均在ASCII范围内，即`[0x0, 0x7f]`：使用的结构为`PyASCIIObject`的布局，字符串内容紧随其后，每个unicode占1字节，并且以0结尾。也就是说这种情况字符串占用的内存大小为`sizeof(PyASCIIObject) + (length + 1) * 1`。因为只存储ASCII字符，这样的存储方式[UTF-8](https://en.wikipedia.org/wiki/UTF-8)编码。
* 当所有字符unicode point最大值在`[0x80, 0xff]`范围内时：使用的结构为`PyCompactUnicodeObject`，字符串内容同样紧随其后。因为所有的unicode point均在`uint8_t`能表示的范围内，每个unicode占1字节，以0结尾。内存占用为`sizeof(PyCompactUnicodeObject) + (length + 1) * 1`。这样的存储方式不符合UTF-8编码，但符合[ISO/IEC 8859-1 (Latin-1)](https://en.wikipedia.org/wiki/ISO/IEC_8859-1)编码。
* unicode point最大值在`[0x100, 0xffff]`范围内时：同样使用`PyCompactUnicodeObject`结构，但unicode point需要用`uint16_t`才能表示，此时每个unicode占2字节，类似地以`(uint16_t)0`结尾。内存占用为`sizeof(PyCompactUnicodeObject) + (length + 1) * 2`。
* 当unicode point最大值在`[0x10000, 0x10ffff]`范围内：此时需要`uint32_t`才能表示，每个unicode占4字节，以`(uint32_t)0`结尾，内存占用`sizeof(PyCompactUnicodeObject) + (length + 1) * 4`。

除去纯ASCII字符的第一种情况，其他情况下的存储方式均不符合[UTF-8编码](https://en.wikipedia.org/wiki/UTF-8)。一个题外话：这种字符串存储方式有利也有弊。其中一个好处是，在查找*第n个字符*时，因为每个字符占用的字节大小是相同的，能够非常快地找到，同样地其他各种字符串算法也会容易实现，而UTF-8编码的字符串实现同样操作会相对麻烦一些。坏处之一是，个别unicode point很大的字符出现在字符串中可能会造成内存占用的大幅增长，例如仅英文的文本中如果插入了一个emoji，相比起同样内容但没有emoji的文本，字符串本身的内存占用会翻4倍，因为emoji的unicode位点都大于0x10000。

如果你曾经编写过Python的C扩展，那么你很有可能用过一个非常实用的接口`PyUnicode_AsUTF8AndSize`。这个接口可以将PyUnicode转为一个C风格UTF-8编码的字符串，并且会返回其长度信息。更方便的是，根据`PyUnicode_AsUTF8AndSize`的[文档](https://docs.python.org/3/c-api/unicode.html)，调用者无需关心其生命周期问题：

> This caches the UTF-8 representation of the string in the Unicode object, and subsequent calls will return a pointer to the same buffer. The caller is not responsible for deallocating the buffer. The buffer is deallocated and pointers to it become invalid when the Unicode object is garbage collected.

但是我们知道，当字符串不是纯ASCII时，PyUnicode中的存储形式并非UTF-8。实际上，文档提到的这一缓存被放进了`PyCompactUnicodeObject`的`utf8`字段，其长度也被记录在`utf8_length`当中。当调用`PyUnicode_AsUTF8AndSize`时，发生的事情如下：

* 如果字符串是纯ASCII的，那么直接返回地址偏移`sizeof(PyASCIIObject)`后的字符串，以及`PyASCIIObject`记录的`length`即可；

* 否则，当`utf8`字段非空时，直接和`utf8_length`一起返回；
* `utf8`字段为空，先通过CPython的UTF-8编码函数[实现](https://github.com/python/cpython/blob/v3.14.0/Objects/unicodeobject.c#L5895)，将其对应的UTF-8表示计算出来。这段内存用`PyMem_Malloc`分配，然后从刚刚的编码结果中复制内容。其地址和长度存入`utf8`和`utf8_length`字段。这之后再返回给调用方。

值得一提的是，当在Python代码中调用`str.encode("utf-8")`时，CPython是不会写入这一缓存的，这一缓存（在笔者目前已知范围内）在C API被调用、需要C风格UTF-8字符串时才会被写入。当PyUnicode引用归零，内存被释放时，`utf8`字段存储的UTF-8表示也会跟着一起被解分配。这也就是为什么调用方无需关心`PyUnicode_AsUTF8AndSize`返回的字符串的解分配。

读到这里你可能已经猜到了：orjson和msgspec在上面测试用例的编解码过程中，产生的gc不掉的内存，来自于**PyUnicode的UTF-8缓存**。

## 序列化

`orjson.dumps`，以及`msgspec.json.encode`，[输出的类型](https://github.com/ijl/orjson/blob/3.11.3/README.md#will-it-serialize-to-str)是UTF-8编码的bytes类型。这一选择和标准库json不同，单从技术选型的角度上来看，不同的人可能会有不同的看法，很难说到底是序列化为`str`更正确或者`bytes`更正确。依笔者个人看法，序列化为UTF-8编码后的`bytes`对象，实际上更符合高性能要求的场景。根据[RFC 8259](https://datatracker.ietf.org/doc/html/rfc8259)，JSON应当以UTF-8编码。主流需求中，对JSON对象做序列化，占多数的是将其作为数据存储到文件/数据库，或者在网络上以字节流的形式发送。对这二者而言，最适合的数据格式当然是UTF-8编码后的字符串格式。在`json.dumps`的参数中，`ensure_ascii`的默认值被设置为true，这样的话能保证输出的JSON字符串是纯ASCII的，PyUnicode中存储内容符合UTF-8编码，从而避免在实际使用时出现额外的UTF-8编码操作导致性能降低；但`ensure_ascii`会导致1个非ASCII字符占用至少6个字节，这样的空间占用也非常不利于存储和传输，而且还会导致JSON文件可读性几乎为零。

但同时，输出`bytes`类型，也给`orjson`和`msgspec`为自己做的benchmark带来了*可以投机取巧的空间*。

先来简单概述一下`orjson.dumps`在处理非ASCII字符串时，到底发生了什么。根据其[源码](https://github.com/ijl/orjson/blob/3.11.3/src/str/pystr.rs#L135)，orjson用一个这样的unsafe函数对PyUnicode做了处理

```rust
    #[inline(always)]
    #[cfg(target_endian = "little")]
    pub fn to_str(self) -> Option<&'static str> {
        unsafe {
            let op = self.ptr.as_ptr();
            if unlikely!((*op.cast::<PyASCIIObject>()).state & STATE_COMPACT == 0) {
                to_str_via_ffi(op)
            } else if (*op.cast::<PyASCIIObject>()).state & STATE_COMPACT_ASCII
                == STATE_COMPACT_ASCII
            {
                let ptr = op.cast::<PyASCIIObject>().offset(1).cast::<u8>();
                let len = isize_to_usize((*op.cast::<PyASCIIObject>()).length);
                Some(str_from_slice!(ptr, len))
            } else if (*op.cast::<PyCompactUnicodeObject>()).utf8_length > 0 {
                let ptr = ((*op.cast::<PyCompactUnicodeObject>()).utf8).cast::<u8>();
                let len = isize_to_usize((*op.cast::<PyCompactUnicodeObject>()).utf8_length);
                Some(str_from_slice!(ptr, len))
            } else {
                to_str_via_ffi(op)
            }
        }
    }
```

总结一下就是

* 当PyUnicode不是compact的（上文提到过常见于`str`的子类对象），用`to_str_via_ffi`创建一个rust的字符串。
* 否则，当PyUnicode是纯ASCII时，使用其本身的数据和长度创建字符串。
* 否则，当`utf8_length`字段的值大于0时，使用**utf8缓存和其长度**创建字符串。
* 否则，用`to_str_via_ffi`创建字符串。

`to_str_via_ffi`函数实际上就是调用`PyUnicode_AsUTF8AndSize`

```rust
fn to_str_via_ffi(op: *mut PyObject) -> Option<&'static str> {
    let mut str_size: pyo3_ffi::Py_ssize_t = 0;
    let ptr = ffi!(PyUnicode_AsUTF8AndSize(op, &mut str_size)).cast::<u8>();
    if unlikely!(ptr.is_null()) {
        None
    } else {
        Some(str_from_slice!(ptr, str_size as usize))
    }
}
```

到这里很显然了，因为`PyUnicode_AsUTF8AndSize`的实现，我们可以发现：只要是一个通常的compact的非ASCII的PyUnicode，被orjson执行`dumps`操作后，其**utf8缓存将必定存在**。当用同一个对象反复执行`orjson.dumps`时，除了第一次调用会因为繁重的`PyUnicode_AsUTF8AndSize`调用变得很缓慢，后续的`orjson.dumps`实际上对字符串对象做的就仅有两件事：将`utf8`字段中的缓存，拷贝到目标JSON字符串的缓冲区；如果有需要用`\`转义的部分就添加`\`进行转义。我们来用一个简单的脚本测试一下，UTF-8缓存能在本文开头那个用例中给`orjson.dumps`节省百分之多少的时间：

```python
import time

import orjson


def get_obj():
    d = {}
    for i in range(16):
        k = "中" * (2**i)
        v = "文" * (2 ** (i + 1))
        d[k] = v
    return d


def do_test(test_cases, func):
    t0 = time.perf_counter()
    for case in test_cases:
        func(case)
    t1 = time.perf_counter()
    return t1 - t0


def test_dumps(func):
    test_cases = [get_obj() for _ in range(1000)]
    ret = do_test(test_cases, func)
    return ret


def test_dumps_cached(func):
    obj = get_obj()
    test_cases = [obj for _ in range(1000)]
    ret = do_test(test_cases, func)
    return ret


time_no_cache = test_dumps(orjson.dumps)
time_cached = test_dumps_cached(orjson.dumps)
time_saved = time_no_cache - time_cached
time_no_cache_per_call = time_no_cache / 1000
time_saved_per_call = time_saved / (1000 - 1)  # except the first call with no cache
time_saved_percent = (time_saved / time_no_cache) * 100

print(f"Time without cache: {time_no_cache:.6f} seconds")
print(f"Time with cache: {time_cached:.6f} seconds")
print(f"Time saved percent: {time_saved_percent:.2f}%")
```

输出如下：

```
Time without cache: 0.356424 seconds
Time with cache: 0.077149 seconds
Time saved percent: 78.35%
```

看起来，我们找到了不见的那四分之三的序列化速度。至此为止我们开头的关于`dumps`的速度和内存占用的悬疑就解开了。至于msgspec，它在这部分的[实现](https://github.com/jcrist/msgspec/blob/0.19.0/msgspec/_core.c#L99)和orjson相差不大

```c
/* XXX: Optimized `PyUnicode_AsUTF8AndSize` for strs that we know have
 * a cached unicode representation. */
static inline const char *
unicode_str_and_size_nocheck(PyObject *str, Py_ssize_t *size) {
    if (MS_LIKELY(PyUnicode_IS_COMPACT_ASCII(str))) {
        *size = ((PyASCIIObject *)str)->length;
        return (char *)(((PyASCIIObject *)str) + 1);
    }
    *size = ((PyCompactUnicodeObject *)str)->utf8_length;
    return ((PyCompactUnicodeObject *)str)->utf8;
}

/* XXX: Optimized `PyUnicode_AsUTF8AndSize` */
static inline const char *
unicode_str_and_size(PyObject *str, Py_ssize_t *size) {
    const char *out = unicode_str_and_size_nocheck(str, size);
    if (MS_LIKELY(out != NULL)) return out;
    return PyUnicode_AsUTF8AndSize(str, size);
}
```

## 反序列化

根据前面的探索，我们大致可以通过内存增幅，猜出来在开头反序列化用例中orjson和msgspec内发生了什么了。为节省篇幅，以下我们只讨论orjson。先说结论：它先将`str`转为了UTF-8编码的字符串，然后再进行反序列化。同样来试试缓存能给orjson带来多少提升：

```python
import json
import time

import orjson


def get_str():
    parts = []
    for i in range(16):
        k = "中" * (2**i)
        v = "文" * (2 ** (i + 1))
        parts.append(f'"{k}":"{v}"')
    return "{" + ",".join(parts) + "}"


def do_test(test_cases, func):
    t0 = time.perf_counter()
    for case in test_cases:
        func(case)
    t1 = time.perf_counter()
    return t1 - t0


def test_loads(func):
    test_cases = [get_str() for _ in range(1000)]
    ret = do_test(test_cases, func)
    return ret


def test_loads_cached(func):
    obj = get_str()
    test_cases = [obj for _ in range(1000)]
    ret = do_test(test_cases, func)
    return ret


time_no_cache = test_loads(orjson.loads)
time_cached = test_loads_cached(orjson.loads)
json_time_cached = test_loads_cached(json.loads)

print(f"orjson time without cache: {time_no_cache:.6f} seconds")
print(f"orjson time with cache: {time_cached:.6f} seconds")
print(f"json time with cache: {json_time_cached:.6f} seconds")
```

输出如下

```
orjson time without cache: 0.495174 seconds
orjson time with cache: 0.222165 seconds
json time with cache: 0.231520 seconds
```

这又引出了新的问题：**为什么有缓存的情况下，速度相比标准库没有显著提升？**

orjson的反序列化逻辑并非是使用rust编写，而是基于一个流行的开源*C语言*JSON解析库[yyjson](https://github.com/ibireme/yyjson)，将其[作为后端](https://github.com/ijl/orjson/tree/3.11.3/include/yyjson)对接使用。本文关心的yyjson的特点主要有两个，一是它反序列化非常快，二是反序列化输出的结构是自定义的一个结构非常简单的数据结构。多数比较易用的JSON库会将JSON array反序列化为支持随机访问的容器，而object反序列化到键值对容器，例如流行的C++ JSON解析库[nlohmann/json](https://github.com/nlohmann/json)会将array和object分别解析为C++中的`std::vector`和`std::unordered_map`，这样会让反序列化的结果非常易于使用。yyjson反序列化array为一个链表，object反序列化的结果也不支持用键在O(1)时间查找值，因此一定程度上可以说yyjson是将性能压力从JSON解析时转移到了访问对象时。

笔者认为在Python或者其他语言的解析库中，选用yyjson作为后端有一个非常直白的优点：它的反序列化有些类似于用非常低的成本，将一个JSON解析到一个“中间表示”，这样就可以非常容易地进行二次处理。orjson实际上通过解析yyjson反序列化得到的结果，二次处理生成Python对象。这就自然地存在一个问题：yyjson作为一个C语言JSON库，其输入和输出字符串都是C风格UTF-8字符串，因此解析非ASCII JSON时，**将其转为UTF-8输入以供yyjson后端处理，以及从yyjson的输出中创建PyUnicode，都要付出额外的代价**。

这样一来上面的问题也解释清楚了。当`loads`的输入为str（PyUnicode）类型时，输入和输出类型都是PyUnicode，逻辑上来讲，和UTF-8沾不上一点边。标准库的json序列化和反序列化，都不涉及任何UTF-8编解码。但`orjson.loads`涉及到两次多余的编码转换，基本可以说是一种“兼容”式的实现，本质上只是让用户不用在传给`orjson.loads`前，再额外写一遍`str.encode("utf-8")`。因为loads时输入的是一整个JSON，最糟糕的一种情况是，当JSON中只要有一个字符是非ASCII字符时，*整个JSON都会被UTF-8编码一次，并记录缓存*，造成巨大的性能浪费。因此，就算yyjson性能再高，也会被orjson的两次额外的UTF-8编解码拖慢。PyUnicode的UTF-8缓存只能用来省下第一步的UTF-8编码的开销，无法避免最后的UTF-8解码的开销。这样一来，开头的问题和前面提出的新问题就都解释清楚了。

## ujson

> ujson维护者已不建议再使用该库，请参见其[Project status](https://github.com/ultrajson/ultrajson?tab=readme-ov-file#project-status)。

ujson是自从Python2时代就开始流行的JSON库。在那时，字符串对象是以字节存储的，假设只考虑UTF-8编码的情况下，JSON dumps实际上只涉及到复制和escape操作，因此用相当直接的实现就能获得很高的性能。但在str内部实现大改的Python3，`ujson.dumps`不能给你带来明确的好处。`ujson.dumps`输出的类型与标准库一样，是str类型，但它先将str编码为UTF-8进行处理，`ujson.loads`同样也有这一问题。在开头的示例中我们可以看到，ujson不会带来额外的内存开销，是因为其核心的字符串编码转换逻辑（[dumps](https://github.com/ultrajson/ultrajson/blob/5.10.0/python/objToJSON.c#L115), [loads](https://github.com/ultrajson/ultrajson/blob/5.10.0/python/JSONtoObj.c#L212)）使用的是`PyUnicode_AsEncodedString`。ujson使用这一接口将PyUnicode编码为UTF-8的bytes类型对象，也就是`PyBytesObject`，然后再从中提取UTF-8字符串。这实际上和在Python代码中写`str.encode("utf-8")`行为是几乎相同的。这一接口生成的PyBytes脱离了原本的PyUnicode的生命周期，而不是进行C风格字符串的生命周期的管理，根据CPython的实现，它并不会记录UTF-8缓存。因此在进行benchmark的时候，对同一对象进行测试，第二次及以后的执行并不会像orjson或者msgspec那样被加速；因为ujson回收掉了这个临时的PyBytes，也不会造成编解码后额外的回收不掉的内存开销。

ujson在写入字符串时，是从前面拿到的UTF-8 bytes解码出unicode，将其值写入一个u32数组，这之后调用`PyUnicode_FromKindAndData`进行字符串创建。也就是说，**ujson自行实现了UTF-8解码逻辑，这一部分的实现相对于CPython的实现更快**，这就是在开头的测试用例中`ujson.loads`速度比orjson和msgspec还快的原因。当`ujson.loads`接受的参数是bytes类型时，整个loads流程就不再涉及到UTF-8解码的性能损耗，因此可以期待在某些非ASCII处理中，ujson能够比orjson和msgspec快。但除此之外，ujson的实现较为naive，编解码使用逐字符的处理，并没有类似orjson那样用SIMD进行快速的字符串复制；对数字以及其他各种类型的字符串转换方案也比较常规。

## 合理的设计

以下从笔者个人的实践经验，来谈谈一个相对理想的高性能Python JSON库应是如何设计的。

* 面向JSON parsing在现实中的实际应用场景（而不是面向benchmark）写实现，否则容易陷入缓存效应等各类陷阱。
* 从使用的角度而言，`dumps`输出UTF-8编码的bytes类型很合适。但我们前面验证过，考虑非ASCII的情况下，这样的选型中，JSON编解码操作中性能消耗占最大头部分很可能会是UTF-8相关的编解码操作。编写高性能JSON三方库的目的就是替代原本标准库虽然兼容性更好但性能较差的实现，那么JSON三方库用高性能的方案来解决UTF-8编解码是一件非常合理的事情。
* dumps时使用或不使用PyUnicode的UTF-8缓存都是正确的实践，但比较好的方案是可以让用户控制是否写入缓存。尤其是，针对仅被dumps一次就销毁的非ASCII字符串对象，[创建缓存](https://github.com/python/cpython/blob/v3.14.0/Objects/unicodeobject.c#L5895)本身会带来至少一次（通常两次）的`PyMem_Malloc`开销和一次复制，以及内存峰值会根据其字符串长度增长；而一个JSON对象中很可能会有成千上万个字符串。在这种情况下，不写入缓存，能收获时间和空间的双赢。
* 从实际工程实践来看，dumps to str仍然非常有用。从Python的设计哲学的角度，str就是最普遍的“字符串”类型。很多库API可能要求一个str输入，如果拿到的是bytes对象，还要执行一次`bytes.decode`才能得到str，这样的接口对用户不友好。以及，如果要对json库做drop-in replacement，dumps输出str会让这一操作变得简单且高效。总的来说，如果库能够支持dumps to str, dumps to bytes, loads from str, 以及loads from bytes，这样的接口就是对用户相当友好的。
* 高效的loads from str实现应当仅涉及到u8, u16和u32三种不同unicode array的复制、转换等操作，而不应涉及任何UTF-8编码相关的操作，dumps to str也是如此。
* 数字的解析、转字符串，应当使用尽可能高效的算法来实现。

那么，有没有符合上述实践的高性能JSON库呢？接下来就需要请出本文的主角[ssrJSON](https://github.com/Antares0982/ssrJSON).

## ssrJSON

[ssrJSON](https://github.com/Antares0982/ssrJSON)是以高性能为导向设计的JSON解析库。

dumps方面，ssrJSON提供`dumps`和`dumps_to_bytes`两种接口，对compact的PyUnicode，JSON dumps（同时包括UTF-8编码）完全使用SIMD实现；`loads`直接基于yyjson的代码结合SIMD重写为完美适合Python的版本，并结合了其他Python JSON库的优点。ssrJSON根据硬件等级自动选取合适的SIMD实现，x86平台支持SSE4.2至AVX512指令集，arm平台支持NEON，且基于Clang高度优化，达到了极致的性能，直至目前（2025年12月，笔者已知范围内）**ssrJSON是综合性能最好的通用Python JSON库**。

下文的benchmark结果均由[ssrJSON-benchmark](https://github.com/Nambers/ssrJSON-benchmark)项目得出，该项目针对现实中常见的JSON用法，以及输入是否有UTF-8缓存等情况，对多个库进行测试，使用C代码对各个库接口调用计时。相比于比较简单且不考虑缓存效应的benchmark，ssrJSON-benchmark得出的结论更加正确。下图是各库相比标准库性能提升比例的分布，ssrJSON明显优于其他JSON库。（下文图表均摘自ssrJSON-benchmark对ssrJSON v0.0.9的[完整测试结果](https://ikuyo.dev/ssrJSON-benchmark/AVX2/i7-13700K_benchmark_result_0.0.9.pdf), 测试环境：Linux, NixOS, Intel i13700k, Python3.14.0）

![](/wp-content/uploads/2025/12/ratio_distribution.v0.0.9.svg)

ssrJSON的`dumps_to_bytes`类似于`orjson.dumps`和`msgspec.json.encode`，输出的类型是bytes类型，但**用户可以控制是否写入UTF-8缓存**。

下面四个柱状图是一个纯中文的[测试用例](https://github.com/Nambers/ssrJSON-benchmark/blob/9207eb70c972200cec44ea3538773590b59b01ad/src/ssrjson_benchmark/_files/simple_object_zh.json)的`dumps_to_bytes`benchmark，用于对比各个库在输出为UTF-8编码的bytes类型的前提下，处理非ASCII的fast path性能。其中json（标准库）和ujson因为不支持直接输出bytes类型，对比时使用的是`dumps(...).encode("utf-8")`进行计时。图一、二是测试无缓存且ssrJSON不写入缓存情况的表现（图二中JSON indent设置为2，注意msgspec不原生支持设置缩进，测试时额外加了一层`msgspec.json.format`调用）；图三是测试输入已经有缓存时各个库的表现；图四和图一一样也是无缓存情况，但启用ssrJSON的缓存写入，用于测试ssrJSON写入缓存时的表现。由于ssrJSON使用SIMD进行UTF-8编码，在无UTF-8缓存的几个测试用例（图一、三、四）中大幅快于其他库。已有缓存的情况（基本就是单纯的内存拷贝速度比拼）比没有缓存的情况更快，而且也明显快于其他库。orjson和msgspec，相比于标准库`json.dumps`后接一个`str.encode("utf-8")`的整个过程，只是将CPython的UTF-8编码调用前置到了JSON处理之前，因此在无缓存情况，并没有取得明显的性能优势。

![](/wp-content/uploads/2025/12/simple_object_zh.json_dumps_to_bytes.v0.0.9.svg)

对于`loads`和`dumps`，结果如下。图一到图四分别是loads from str, loads from bytes, dumps to str, dumps to str with indent=2（注意msgspec不原生支持设置缩进，测试时额外加了一层`msgspec.json.format`调用）。前面我们已经讨论过，其他三方库loads from str的原生实现性能很差；ssrJSON的loads from str因为采用了正确的实现（不涉及UTF-8编解码），性能很好。在其他几个库擅长的领域loads from bytes，ssrJSON仍然是最快的，ujson因为没有额外的性能浪费而排在第二。对于dumps to str的两个测试，ssrJSON凭借高效的SIMD内存拷贝达到了标准库10倍以上的速度；由于orjson和msgspec输出的是bytes类型，benchmark分别采用的是`orjson.dumps(...).decode("utf-8")`以及`msgspec.json.encode(...).decode("utf-8")`进行计时，它们本身dumps性能就不高，再加上decode操作，因此表现不好是能预料的；`ujson.dumps`输出的直接就是str类型，但由于其内部实现中UTF-8编码后再解码的操作，性能被折腾没了，比`orjson.dumps`后面接一个decode还慢一些。

![](/wp-content/uploads/2025/12/simple_object_zh.json_load&dump.v0.0.9.svg)

ASCII情况，ssrJSON同样表现优异。对于常见的JSON性能测试用例[github.json](https://github.com/Nambers/ssrJSON-benchmark/blob/9207eb70c972200cec44ea3538773590b59b01ad/src/ssrjson_benchmark/_files/github.json)，该文件主要是ASCII字符，ssrJSON仍然是最快的，相比orjson稍快或更快。（部分纯ASCII测试用例中ssrJSON性能和orjson各有千秋，见[完整测试结果](https://ikuyo.dev/ssrJSON-benchmark/AVX2/i7-13700K_benchmark_result_0.0.9.pdf)）

![](/wp-content/uploads/2025/12/github.json_dumps_to_bytes.v0.0.9.svg)

![](/wp-content/uploads/2025/12/github.json_load&dump.v0.0.9.svg)

另一个常见的benchmark用例[twitter.json](https://github.com/Nambers/ssrJSON-benchmark/blob/9207eb70c972200cec44ea3538773590b59b01ad/src/ssrjson_benchmark/_files/twitter.json)，它非常类似现实场景中网络上传输的JSON数据，ssrJSON具有明显优势。

![](/wp-content/uploads/2025/12/twitter.json_dumps_to_bytes.v0.0.9.svg)

![](/wp-content/uploads/2025/12/twitter.json_load&dump.v0.0.9.svg)

[canada.json](https://github.com/Nambers/ssrJSON-benchmark/blob/9207eb70c972200cec44ea3538773590b59b01ad/src/ssrjson_benchmark/_files/twitter.json)也是一个常见的benchmark用例，几乎全部由浮点数组成。ssrJSON采用[Dragonbox](https://github.com/jk-jeon/dragonbox)算法进行浮点数字符串转换，其`dumps`和`dumps_to_bytes`的速度直观地展现了Dragonbox的威力（2026.03.15 Update: 现在使用[xjb](https://github.com/xjb714/xjb)，比Dragonbox更快了）。`loads`方面，浮点字符串解析则是基于[yyjson](https://github.com/ibireme/yyjson)高效的解析算法，整体表现也比其他库好很多。（因为这个用例完全没有非ASCII字符，UTF-8缓存相关的两个测试和一般的dumps_to_bytes测试没区别，因此没有进行）

![](/wp-content/uploads/2025/12/canada.json_dumps_to_bytes.v0.0.9.svg)

![](/wp-content/uploads/2025/12/canada.json_load&dump.svg)

## 怎么做？

### 使用ssrJSON

假设你的项目对性能非常敏感，推荐尝试用[ssrJSON](https://github.com/Antares0982/ssrJSON)替换你正在使用的JSON库。你可以直接用pip安装：

```
pip install ssrjson
```

或者直接将源码整合到你的C/C++项目中使用，注意ssrJSON仅支持Clang工具链。

使用方面，因为ssrJSON的dumps/loads接口设计兼容标准库，直接的替换是非常容易的。如果你使用标准库json的dumps和loads，可以尝试用

```python
import ssrjson as json
```

来做drop-in replacement。如果是其他三方库，可以用`ssrjson.dumps_to_bytes`和`ssrjson.loads`做替换。针对一些性能比较敏感的地方，用`ssrjson.dumps_to_bytes`替换原本的实现来达到更快的速度；根据项目情况，通过`ssrjson.write_utf8_cache(False)`来全局关闭`dumps_to_bytes`的UTF-8缓存写入；或针对个别用法，向`dumps_to_bytes`传入`is_write_cache=False`来对单个调用关闭UTF-8缓存的写入。整个替换过程应当是非常简单的，但需要注意ssrJSON虽参数兼容，却并不保证一些标准库支持的功能，细节请参考[README: features](https://github.com/Antares0982/ssrjson?tab=readme-ov-file#features)一节。

一些情况下ssrJSON可能不能满足你的需求，它目前处于Beta阶段，主体功能已经稳定，但部分支持受限。

* ssrJSON对操作系统不是非常挑剔，但对硬件有要求，目前仅支持64位的x86或ARM架构。x86 CPU要求至少有SSE4.2，即[x86-64-v2](https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels)（根据steam的[硬件调查结果](https://store.steampowered.com/hwsurvey/Steam-Hardware-Software-Survey-Welcome-to-Steam)，99.5%的x86 CPU都满足条件）。
* 部分次要功能缺失，如`loads`没有实现`object_hook`，尚未支持free-threading (no GIL)的Python build（都在其feature计划中）。解决方案：向ssrJSON提交pull request实现对应功能；提交feature request，等到ssrJSON实现了该feature。
* 使用时发现ssrJSON有bug。解决方案：向还在Beta阶段的ssrJSON提交PR修复，或提出issue，让其逐渐完善。

更多ssrJSON相关的细节，请参考其项目主页的[README](https://github.com/Antares0982/ssrjson?tab=readme-ov-file)。如果这篇文章对你有用，不妨给[ssrJSON](https://github.com/Antares0982/ssrJSON)点一个免费的star `:)`
