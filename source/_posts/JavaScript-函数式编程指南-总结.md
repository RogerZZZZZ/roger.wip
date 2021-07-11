---
title: <<JavaScript 函数式编程指南>> 总结
date: 2021-07-11 21:35:34
tags:
  - 读书笔记
  - javascript
categories:
  - 读书笔记
---

## 函数式的意义

整本书阅读下来, 我认为有三点吧:

- 纯函数的意义, 固定输入 => 固定输出, 对于单元测试, 自动化测试友好.
- 复杂任务的分解, 相比于命令式来说, 代码意图更加明显, 增加可维护性.
- 有助于代码功能的拆分以及功能的模块化, 代码的逻辑可以用类似搭积木的方式完成.

但是, 函数式优雅的同时, 性能并不优雅.

- 过度使用柯里化, 会导致函数执行栈过深
- 每一次map, filter, reduce其实都遍历了一遍数组, 所有类似lodash这样的库才会对这样的链式调用或者是compose组合式调用进行优化, 合并连接在一起的map, filter函数

## 一些有意思的概念

### 高阶函数

可以接收其他函数作为参数的js函数, 均属于一种函数类型, 高阶函数
> 可以联想到React中的HOC

### 函数组合子

> 组合子是一些可以组合其他函数, 并作为控制逻辑运行的高阶函数

1. identity ( I-combinator )

identity组合子是返回与参数同值的函数

```
identity :: (a) -> a
```

2. tap ( K-组合子 )

> 将无返回值的函数嵌入函数组合中, 它会将所属对象传入函数参数并返回该对象

```
tap :: (a -> *) -> a -> a
```


```js
const debug = R.tap(debugLog)
const isValidSsn = R.compose(debug, checkLengthSsn, debug, cleanInput);
```

3. alt ( OR-组合子 )

```js
const alt = R.curry((func1, func2, val) => func1() || func2())
```

4. fork ( join组合子 )

```js
const fork = function(join, func1, func2) {
  return function(val) {
    return join(func1(val), func2(val))
  };
}
```

### 函数式对于执行错误的处理方式

我们在实际编程的过程中, 处理错误的大多数方式为`try catch`, 而对于函数式来说, 不应该抛出异常, 理由如下

1. 难以与其他函数进行组合或者链接
2. 违反了引用透明性, 因为抛出异常会导致函数调用出现另外的出口, 不能确保单一的可预测的返回值
3. 违反局限性的原则, 因为用于恢复异常的代码与原始的函数调用渐行渐远, 当发生错误以后, 函数离开局部栈与环境

接来下我们看下函数式如何处理错误, 首先给出一个概念`Functor`

#### **Functor**

> Functor只是一个可以将函数应用到它包裹的值上, 并将结果再包裹起来的数据结构

```
fmap :: (A -> B) -> wrap(A) -> wrap(B)

接受一个从A->B的函数, 以及一个wrap(A) Functor, 然后返回包裹着结果的新Functor wrap(B)
```

```js
const plus = R.curry((a, b) => a + b);
const plus3 = plus(3);

const two = wrap(2);
const five = two.fmap(plus3) // wrap(5)
five.map(R.indentity) // -> 5
```

但是`Functor`本身并不知道如何处理null, 当在执行过程中出现null值的时候, 依旧会报错, 此时我们引入一个更为具体化的函数式数据结构`Monad`, 旨在安全的传递错误. 此处可以联想到`jQuery`

```js
$('#id').width().height().attribute()....
// 就算#id不存在, 也不会导致执行错误
```

#### Maybe Monad / Either Monad

这两个概念类似, 我们就举一个例子就好. 此处以Maybe Monad为例.

> Maybe Monad侧重于整合`null`的判断逻辑, Maybe是一个包含两个具体子类型的空类型

- Just(value) - 表示值容器
- Nothing() - 表示要么没有值或者没有失败的附加信息, 当然, 还可以应用到Nothing上

其实简单的做法就是在执行过程中, 如果存在null值, 就把wrap转为Nothing即可

```js
const safeFindObject = R.curry(function(db, id) {
  return Maybe.fromNullable(find(db, id));
});

Maybe.prototype.fromNullable = (a) => {
  return a !== null ? new Just(a) : new Nothing();
}
```

#### 递归和尾递归优化

```js
const factorial = (n, current = 1) => {
  if (n === 1) {
    return current;
  }
  return factorial(n - 1, n * current) // 函数最后一条语句是下一次递归时, 性能接近for语句
}
```

> 如果函数的最后一件事情是执行一个递归函数, 那么运行时会认为不必要保持当前的栈帧, 因为所有工作已经完成了.