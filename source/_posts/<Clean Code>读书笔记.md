---
title: <Clean Code读书笔记>
date: 2021-05-10 23:55:10
tags:
  - 读书笔记
categories:
 - 读书笔记
---

## 前言

这本书断断续续终于最后还是读完了, 很多都是老生常谈的东西, 但其中不乏也有一些有意思值得记忆的点

这里就记录一下

<!-- more -->

## 重构Args, 第14章

其中印象比较深刻的有:

1. `Exception类`的封装和使用
2. `HashMap<Character, ArgumentMarshaller>`的实现和使用, 对ArgumentMarshaller有不同的实现, 比如`IntegerMarshaller`, `BooleanMarshaller`等, 然后不同的marshaller实现不同的get, set方法

## 第17章, 味道与启发

大部分内容都在`重构-改善既有代码的设计`这书中有提及. 但有几个点值得在这里记录一下.

1. 选择算子参数

```java
public int calculateWeeklyPay(boolean overtime) {}
```

调用的时候就会出现`calculateWeeklyPay(true)`, 导致阅读者非常的诧异. 这样的情况应当把函数功能进行拆分, 拆分为类似`straightPay`以及`overTimePay`两个函数

2. 掩蔽时序耦合

```java
public void dive(String reason) {
  saturateGradient();
  reticulateSplines();
  diveForMoog(reason);
  // 编绳 -> 织网 -> 捕鱼 存在顺序关系, 但是对于阅读者来说失去了时序信息, 会导致潜在bug
}
```

```java
// 更好的写法
public void dive(String reason) {
  Gradient gradient = saturateGradient();
  List<Spline> splines = reticulateSplines(gradient);
  diveForMoog(splines, reason);
}
// 强制了调用顺序
```

3. 不要继承常量

```java
public class HourlyEmployee extends Employee {}

public class Employee implements PayrollConstants {}

public interface PayrollConstants {
  public static final int TENTHS_PRE_WEEK = 400;
}
```

应该改为静态导入

```java
import static PayrollConstants.*
```