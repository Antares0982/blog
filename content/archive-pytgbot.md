---
title: "python tgbot自制代码模板"
slug: "archive-pytgbot"
date: 2023-10-13T23:51:43+08:00
lastmod: 2023-10-13T23:51:43+08:00
wpid: 343
wpguid: "https://chr.fan/?page_id=343"
views: 3111
hidden: true
url: "/archive/archive-pytgbot/"
---

> **TL;DR**： GitHub仓库在[这里](https://github.com/Antares0982/telegram-bot-template)

自从学会使用`python-telegram-bot`包之后，我一直觉得实际编写程序的时候这个包有一些地方不太方便。比如：

* 每次给bot添加一个新的command，就需要

  ```python
  updater.dispatcher.add_handler(CommandHandler("command", command))
  ```

  而实际编写的时候常常会忘记要添加这个`CommandHandler`，等到开始测试的时候才发现，于是又要改代码。而且，一般而言我会把callback函数名和指令名字写成完全一样的，添加handler的时候重复打一次指令名还要加个双引号是一件很头疼的事情。之前写的dicebot里，我是这样处理的：将所有handlers写在同一个文件里，之后import这个只定义了handlers的文件，并遍历里面全部的函数来添加handler。这样做有两个坏处，其中一个就是handlers的文件import别的文件时，如果那个文件`dum`有定义函数`fun`，就不能`from dum import fun`或者`from dum import *`，只能`import dum`，然后要调用`fun`时就需要`dum.fun()`，非常麻烦。第二个坏处是，每个command都是由几个功能更少的函数组合起来的，这些函数必须要写在别的文件里，破坏了代码的可读性。

* 每个`commandHandler`接收到消息时，获取消息来源的聊天、用户等信息是非常基本的事情，基本上每个命令都需要做这件事。是否可以在每个command前固定执行一些语句来获取这些基础信息呢？

* 该包提供的功能里，一条消息仅仅能被一个handler处理，不能像酷Q机器人一样，按照顺序先传给第一个handler，如果这个handler不处理就传给下一个，被其中一个handler处理了的话就停止。如果在一个bot上想要实现多个功能就会比较困难。
* 如果bot架设在大陆并使用代理的话，经常会出现消息发送失败的情况，以及消息过长时，会出现超过字数限制，无法发送的情况。这时如果正在执行某个handler，并且这个handler的实现没有用try语句将发送消息的函数包裹住的话，这个command就会被迫停止。如果能够多尝试发送几次，说不定代理不稳定的问题就能得以解决。当超出字数限制时，就需要将消息分成几段发送。

## 思考&尝试

为了尝试解决第一个问题，首先需要使用类，这个类表示一个tgbot，并将handler以及实际实现它的子函数都写为类的方法。可以给方法前加上一个类装饰器，在初始化需要用`add_handler`时，遍历所有成员方法，判断它的类型是否是该装饰器的类型，如果是则添加到handlers即可。这样的话，在调用类装饰器的`__call__`之前，可以先调用一个预执行的方法，就顺带解决了第二个问题。

至于第三个问题，一般而言需要多个handler的情况是：有多个功能需要文本、按钮交互。但按钮和文本只能被一个handler来执行。可以直接参考酷Q机器人的做法，让这些handlers只返回`passed`或者`blocked`这样的信号，最后，用一个方法作为直接被`add_handler`接收的方法，这个方法的作用只有按顺序传给这些handlers，如果其中一个返回了`blocked`状态，就结束运行，否则继续往下传递给其他handlers。这样的话，又要考虑遍历全部handlers的问题了。于是我想到，这里可以用菱形继承来解决这个问题。

第四个问题则只需要重新定义一个消息发送函数即可，如果在第二个问题提到的预执行函数中获取到了聊天信息，消息发送函数甚至只需要一个字符串作为参数就可以了，因为聊天信息可以存储在对象中。这样不会产生消息发错人的问题，因为`python-telegram-bot`的消息处理是阻塞的而非并发的。

## 基本结构

首先定义一个基本的类

```python
class baseBot(object):
    def __init__(self):
        if proxy:
            self.updater = Updater(token=token, use_context=True, request_kwargs={
                                   "proxy_url": proxy_url})
        else:
            self.updater = Updater(token=token, use_context=True)
    	...
```

基本类`baseBot`只实现最基础的功能，然后实际的功能类全部继承`baseBot`，每个类实现一个具体的功能：

```python
class exampleBot1(baseBot):
    def __init(self):
        if not hasattr(self, "updater"):
            baseBot.__init__(self)
        ...

class exampleBot2(baseBot):
    def __init(self):
        if not hasattr(self, "updater"):
            baseBot.__init__(self)
        ...

```

最后，用一个最终类继承全部功能类：

```python
class finalBot(exampleBot1, exampleBot2):
    def __init__(self):
        for cls in self.__class__.__bases__:
            cls.__init__(self)    
```

## commandHandler专用的装饰器

`CommandHandler`的`callback`必须能接收两个参数，一个是`Update`类型，一个是`CallbackContext`类型。可以直接用比较朴素的方法实现下面的`commandCallbackMethod`，但是问题在于，最终实际调用时要调用的`__wrapped__`需要`baseBot`对象，以及需要在预执行函数里将聊天信息存入`baseBot`对象，就必须获取到这个对象的引用。好在每次调用时，`__get__`函数会被执行一次，此时会传入`instance`，这样就能方便地获取到方法从属的对象的一个引用了。

这里使用`TYPE_CHECKING`来提供类型检查功能，因为这个文件`utils`是要被`baseBot`文件import的，为了防止循环import，在本文件中对`baseBot`的import要在`if TYPE_CHECKING:`语句下面，并且用引号框起来它的类型。这样在实际执行的时候，因为`TYPE_CHECKING`常数为`False`，就不会造成循环import。当然，只是为了类型检查而import的`CallbackContext`也可以放在这里减少实际执行时的import。

这里预执行函数是baseBot的一个方法`renewStatus(update)`，可以获取到`update`里的`chat`，`from_user`等信息。

```python
# utils
from typing import TYPE_CHECKING, Callable, TypeVar
from telegram import Update
from typing_extensions import final
if TYPE_CHECKING:
    from telegram.ext import CallbackContext
    from basebot import baseBot
RT = TypeVar('RT')

...

@final
class commandCallbackMethod(object):
    """表示一个指令的callback函数，仅限于类的成员方法。
    调用时，会执行一次指令的前置函数。"""

    def __init__(self, func: Callable[[Update, 'CallbackContext'], RT]) -> None:
        wraps(func)(self)
        self.instance: 'baseBot' = None

    def __call__(self, *args, **kwargs):
        numOfArgs = len(args)+len(kwargs.keys())
        if numOfArgs != 2:
            raise RuntimeError(f"指令的callback function参数个数应为2，但接受到{numOfArgs}个")
        if len(args) > 0:
            self.preExcute(args[0])
        else:
            if all(type(kwargs[x]) is not Update for x in kwargs):
                raise RuntimeError("指令接收到的参数类型有误，第一个参数应为Update")
            for key in kwargs:
                if type(kwargs[key]) is Update:
                    self.preExcute(kwargs[key])
                    break
        return self.__wrapped__(self.instance, *args, **kwargs)

    def preExcute(self, update: Update) -> None:
        """在每个command Handler前调用，是指令的前置函数"""
        if self.instance is None:
            raise RuntimeError("command callback method还未获取实例")
        self.instance.renewStatus(update)

    def __get__(self, instance, cls):
        if instance is None:
            raise TypeError("该装饰器仅适用于方法")
        if self.instance is None:
            self.instance = instance
        return self
```

`renewStatus()`实现如下，其中的几个没具体写的函数都只返回一些基本信息，看名字就知道是干啥的。

```python
# baseBot

class baseBot(object):
    ...
    
    def renewStatus(self, update: Update) -> None:
        """在每个command Handler前调用，是指令的前置函数"""
        self.lastchat = getchatid(update)
        if update.callback_query is None:
            self.lastuser = getfromid(update)
            self.lastmsgid = getmsgid(update)
        else:
            self.lastuser = update.callback_query.from_user.id
            self.lastmsgid = -1
```

## 定义handleStatus

`handleStatus`类只需要两个bool类型就完全足够了：一个代表是否blocked，一个代表执行是否正常进行。实际上后者是完全不必要的，我有时为了方便才会需要这样返回值。所以bool完全可以替代`handleStatus`类。

```python
# utils

class handleStatus(object):
    def __init__(self, normal: bool, block: bool) -> None:
        self.block: bool = block
        self.normal: bool = normal

    def __bool__(self):
        ...

    def blocked(self):
        return self.block


@final
class handleBlocked(handleStatus):
    def __init__(self, normal: bool = True) -> None:
        super().__init__(normal=normal, block=True)

    def __bool__(self):
        return self.normal


@final
class handlePassed(handleStatus):
    def __init__(self) -> None:
        super().__init__(True, False)

    def __bool__(self):
        return True
```

接下来才是实际问题。`finalBot`继承所有功能类之后，可以用`self.__class__.__bases__`遍历所有父类的某个固定方法，这时候对返回的`handleStatus`对象进行block与否的判断，即可正常执行。遍历时，是按照继承顺序从左到右遍历，所以要将高优先级的功能类写在左边。

给`baseBot`定义方法，但不进行任何实现：

```python
class baseBot(object):
    ...
    
    def textHandler(self, update: Update, context: CallbackContext) -> handleStatus:
        """Override"""
        return handlePassed()
```

功能类实现方法：

```python
# file1

class exampleBot1(baseBot):
    ...
    
	def textHandler(self, update: Update, context: CallbackContext) -> handleStatus:
        if not cond1:
            return handlePassed()
        dosth1()
        return handleBlocked()

# file2

class exampleBot2(baseBot):
    ...
    
    def textHandler(self, update: Update, context: CallbackContext) -> handleStatus:
        if not cond2:
            return handlePassed()
        dosth2()
        return handleBlocked()
```

最终的类：

```python
class finalBot(exampleBot1, exampleBot2):
    ...
    
    def textHandler(self, update: Update, context: CallbackContext) -> bool:
        self.renewStatus(update) # 预执行函数
        for cls in self.__class__.__bases__:
            status: handleStatus = cls.textHandler(self, update, context)
            if status.blocked():
                return status.normal
        return False
```

实际实现这些方法的时候，判断是否满足要在该方法中处理的条件，如果不在该方法中处理就返回`handlePassed()`，否则，正常处理之后返回`handleBlocked()`，处理出现异常则返回`handleBlocked(False)`。

## 额外的消息发送函数

如果每个handler执行前都获取到了`lastchat`，`lastuser`，`lastmsgid`等信息，那么如下的实现可以让我们把回复消息的语句直接写成`self.reply(msg)`，方便不少。

```python
class baseBot(object):
    ...
    
    def reply(self, *args, **kwargs) -> int:
        """调用send_message方法，回复或发送消息。
        支持telegram bot中`send_message`方法的keyword argument，
        如`reply_markup`，`reply_to_message_id`，`parse_mode`，`timeout`。
        返回值是message id"""
        ans = None
        chat_id: Optional[int] = None
        text: str = None
        if len(args) > 0:
            if type(args[0]) is int:
                chat_id = args[0]
                kwargs["chat_id"] = chat_id
            elif type(args[0]) is str:
                text = args[0]
                kwargs["text"] = text

            if len(args) > 1:
                assert(type(args[0]) is int)
                assert(type(args[1]) is str)
                text = args[1]
                kwargs["text"] = text

        if chat_id is None and "chat_id" in kwargs:
            chat_id = kwargs["chat_id"]

        if text is None and "text" in kwargs:
            text = kwargs["text"]

        if not text:
            raise ValueError("发生错误：发送消息时没有文本")

        if chat_id is None:
            kwargs["chat_id"] = self.lastchat
            if self.lastmsgid >= 0 and "reply_to_message_id" not in kwargs:
                kwargs["reply_to_message_id"] = self.lastmsgid

        txts = text.split("\n")

        if len(txts) > 10 and len(text) >= 1024:
            while len(txts) > 10:
                kwargs["text"] = "\n".join(txts[:10])
                txts = txts[10:]
                for i in range(5):
                    try:
                        ans = self.bot.send_message(**kwargs).message_id
                        if "reply_markup" in kwargs:
                            kwargs.pop("reply_markup")
                    except Exception as e:
                        if i == 4:
                            raise e
                        time.sleep(5)
                    else:
                        break

        if len(txts) > 0:
            kwargs["text"] = "\n".join(txts)
            for i in range(5):
                try:
                    ans = self.bot.send_message(**kwargs).message_id
                except Exception as e:
                    if i == 4:
                        raise e
                    time.sleep(5)
                else:
                    break

        if ans is None:
            raise ValueError("没有成功发送消息")
        return ans

```

实际上，这个方法支持的用法很多，比如：

```python
self.reply(tgid, msg) # 给某人发送消息
self.reply(msg, reply_markup=rp_markup) # 发送带按钮的文本
self.reply(msg, reply_to_message_id=None) # 发送消息时不回复消息
self.reply(msg, parse_mode="MarkdownV2")
```

用同样的方法也可以重新实现`delete_message`，`edit_message_text`等函数。

## 小结

实际上我已经用这个模板写了一个bot，有在Telegram使里用ssh连VPS、搜图以及闹钟三个功能，用这个模板的话，之后能非常轻松地进一步扩展bot的功能。这个[模板](https://github.com/Antares0982/telegram-bot-template)已经放在GitHub上，如果你觉得有用的话，不妨点个Star。
