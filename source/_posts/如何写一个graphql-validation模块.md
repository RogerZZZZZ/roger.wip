---
title: 如何写一个graphql validation模块
date: 2021-01-18 21:40:43
tags:
  - Front End
  - graphql
categories:
  - Front End
---

## 前言

写这篇文章的契机是因为最近项目中使用到了`graphql`, 为了防止接口出现安全问题, 就对`graphql`的`validation`进行了一点研究. 本文就不对`graphql`进行一些介绍了, 如果感兴趣的小伙伴, 可以移步到官网进行阅读[链接](https://graphql.org/)

<!-- more -->

## 初级的防御

### 1. 关闭内省系统


首先我们要知道内省是什么, 内省也可以被认为是自检系统. 通过内省我们可以简单的就获取到`graphql`支持的所有查询以及查询字段的类型, 这里举一个例子, 你可以使用`__schema`来询问`graphql`有哪些类型是可用的

```graphql
{
  __schema {
    types {
      name
    }
  }
}
```

```graphql
{
  "data": {
    "__schema": {
      "types": [
        {
          "name": "Query"
        },
        {
          "name": "Episode"
        },
        {
          "name": "ID"
        },
        {
          "name": "String"
        },
        // .....
        {
          "name": "Int"
        },
        {
          "name": "__Type"
        },
        {
          "name": "__TypeKind"
        },
        {
          "name": "__Field"
        },
      ]
    }
  }
}
```

- 类似`Query`, `Episode`这是我们再类型系统中定义的类型
- `Int`, `String`这样是内建的标量, 由系统提供
- `__Type`, `__TypeKind`这些则为内省系统中的一部分

我们如何知道一个类型支持哪些字段, 而其中的字段又是什么类型呢

```graphql
{
  __type(name: "Droid") {
    name
    fields {
      name
      type {
        name
        kind
      }
    }
  }
}
```

```graphql
{
  "data": {
    "__type": {
      "name": "Droid",
      "fields": [
        {
          "name": "id",
          "type": {
            "name": null,
            "kind": "NON_NULL"
          }
        },
        {
          "name": "name",
          "type": {
            "name": null,
            "kind": "NON_NULL"
          }
        },
        {
          "name": "friends",
          "type": {
            "name": null,
            "kind": "LIST"
          }
        },
        {
          "name": "friendsConnection",
          "type": {
            "name": null,
            "kind": "NON_NULL"
          }
        },
        {
          "name": "appearsIn",
          "type": {
            "name": null,
            "kind": "NON_NULL"
          }
        },
        {
          "name": "primaryFunction",
          "type": {
            "name": "String",
            "kind": "SCALAR"
          }
        }
      ]
    }
  }
}
```

其中`NON_NULL`表示是一个非空的包装, 可以通过`ofType`来获取其类型.

上面只是举了一些内省系统中几个简单的应用, 那么说到这里, 聪明的小伙伴就会发现这样的系统能给我们带来什么了, 对了, 那就是大家最讨厌的`文档`.

schema的编写本质就能生成一份完善的文档, 这里介绍一个现成的工具可以使用, [graohql-doc](https://github.com/mhallin/graphql-docs)

我们知道文档都是对内的, 如果将所有文档暴露在外势必会引起安全问题, 所以我们在生产环境中需要关闭内省系统

这里以`express`作为例子

```js
import express from 'express';
import bodyParser from 'body-parser';
import { graphqlExpress } from 'graphql-server-express';
import NoIntrospection from 'graphql-disable-introspection';

const myGraphQLSchema = // ... define or import your schema here!
const PORT = 3000;

var app = express();

// bodyParser is needed just for POST.
app.use('/graphql', bodyParser.json(), graphqlExpress({
  schema: myGraphQLSchema,
  validationRules: [ NoIntrospection ]
}));

app.listen(PORT);
```

### 2. 对Query的DDos防御

`graphql`带给了前端方便的同时, 也为服务端带来了很多不确定性, 比如下面的`query`无限循环下去将会给服务器带来ddos攻击

```graphql
query getBlogDDos {
  author(id: "abc") {
    name                    # Depth: 1
    blog {                  # Depth: 2
      author {              # Depth: 3
        name
        blog {              # Depth: 4
          author {          # Depth: 5
            name
            blog {          # Depth: 6
              author {      # Depth: 7
                name
                blog {      # Depth: 8
                  # ......
                }
              }
            }
          }
        }
      }
    }
  }
}
```

这样的场景解决方法也非常的简单, 通过`AST`分析`query`的深度并对其进行限制即可. 如果查询深度超过预设值, 则返回错误

```json
{
  "errors": [
    {
      "message": "Query has depth of 8, which exceeds max depth of 5"
    }
  ]
}
```

通过深度对`graphql`的query进行安全检查有明显的优势, 但是也有更加明显的缺点, 如果在根节点进行大量的查询一样会造成ddos攻击, 所以我们需要引入另外的方法来对`query`进行校验.

## 防御加固

### 1. 查询的复杂度计算

查询复杂度的计算方式有很多种, 这里我们只举出一个例子, 首先我们假设查询一个基础类型字段的复杂度为`1`, 深度每`+1`(深度变化可能是列表也可能是自定义的数据结构), 就导致基础的倍数`*10`

```graphql
query {
  author(id: "abc") {
    name                 # complexity: 1
    id                   # complexity: 1 + 1
    posts {
      title              # complexity: 1 + 1 + 1 * 10
      id                 # complexity: 1 + 1 + 1 * 10 + 1 * 10
    }
  }
}
```

上述`query`的复杂度为`22`, 


### 2. 校验工具实现

现在进入本文的重点, 我们如何实现一个这样的校验工具呢, 首先看到对一个`query`的遍历, 我们能很容易的联想到深度优先算法, `graphql`官方也提供了这样的遍历函数方便开发者使用.

```js
function visit(root, visitor, keyMap) {
  // ....
}

// 提供了enter, leave两个函数, 当进入/离开一个node会触发
const editedAst = visit(ast, {
  enter(node, key, parent, path, ancestors) {

  },
  leave(node, key, parent, path, ancestors) {

  }
})
```

当然你可以指定`enter`, `leave`函数绑定的`node`类型

```js
visit(ast, {
  Kind: {
    enter(node) {
      // enter the "Kind" node
    }
    leave(node) {
      // leave the "Kind" node
    }
  }
})
```

接下来是`visit`函数在`validation`中的实际使用方法

```js
function createComplexityLimitRule(
  maxCost,
) {
  return function ComplexityLimit(context) {
    const visitor = new ComplexityVisitor(context);
    const typeInfo = context._typeInfo || new TypeInfo(context.getSchema());

    return {
      Document: {
        enter(node) {
          // 此处的vistor为我们自定的遍历逻辑, 接下来会细讲
          visit(node, visitWithTypeInfo(typeInfo, visitor));
        },
        leave(node) {
          const cost = visitor.getCost();
          if (cost > maxCost) {
            context.reportError(
              createError
                ? createError(cost, node)
                : new GraphQLError(formatErrorMessage(cost), [ node ])
            );
          }
        },
      },
    };
  };
}
```

> 这里也贴上[`visitWithTypeInfo`](https://npmdoc.github.io/node-npmdoc-graphql/build..beta..travis-ci.org/apidoc.html#apidoc.element.graphql.visitWithTypeInfo)的实现

`ComplexityVisitor`的实现核心为在构造函数中申明需要遍历的`Node Type`

```js
this.Field = {
  enter: this.enterField,
  leave: this.leaveField,
};
```

接下来的逻辑就非常简单了, 只需要在`enterField`和`leaveFiled`中补充相应的逻辑就好了

```js
enterField() {
  this.costFactor *= this.getFieldCostFactor();

  this.cost += this.costFactor * this.getFieldCost();
}

leaveField() {
  this.costFactor /= this.getFieldCostFactor();
}
```

这里还有两个函数比较重要, 一个是`getFieldCostFactor`, 这个函数的作用是当遇到嵌套结构, 例如自定义数据结构或者列表时候, 增大复杂度系数. 另一个为`getFieldCost`, 这个是计算改`node`的实际cost, 并累加到总复杂度中.

```js
// 可以通过传入配置的方式, 改变不同node的复杂度, 定制自己的复杂度计算规则
const options = {
  scalarCost = 1,
  objectCost = 0,
  listFactor = 10,
  ...injectOptions
}
```

但是目前这样只能仅限于全局设置, 而不能对一个`query`进行自定义的复杂度计算, 并且对于不同field的开销肯定不同的, 于是我们可以通过拓展`extensions`的方式, 改变单一`field`或者`list`的复杂度. 例如:

```graphql
directive @cost(value: Int) on FIELD_DEFINITION
directive @costFactor(value: Int) on FIELD_DEFINITION

type CustomCostItem {
  expensiveField: ExpensiveItem @cost(value: 50)
  expensiveList: [MyItem] @costFactor(value: 100)
}
```

对应的我们需要更改`getFieldCostFactor`以及`getFieldCost`函数的实现, 此处以`getFieldCost`为例

```js
getFieldCost() {
  const fieldDef = this.context.getFieldDef();
  if (fieldDef.extensions && fieldDef.extensions.getCost) {
    return fieldDef.extensions.getCost();
  }

  return this.getTypeCost(this.context.getType());
}
```

最后我们只需要提供出`getCost`方法将累加的复杂度结果透出. 在外层的`Document.leave`处对复杂度总和进行判断, 如果超过之前设置的阈值, 则抛出一个异常即可.

到这里我们就简单的实现了一个`graphql`的校验插件, 当然在文章前半部分提到的`深度判断`也可以用类似的方法快速实现

## 补充

上面所说的查询复杂度计算也存在问题, 我们很难完美的实现对一个query复杂度的判断

所以这里我们还能通过`节流`的方式限制服务器处理单一`query`的次数

```graphql
query {
  author(id: "abc") {
    name
  }
}
```

假设执行上面查询的时间为100ms, 我们可以设置服务器处理这个查询的`最大服务器时间`为600ms, 每隔1s能够增加100ms的`服务器时间`, 如果服务器的`服务器时间`不够执行上面的查询, 则拒绝服务. 但是问题是我们需要对上面的查询时间有一个预估, 但这有可能是不准确. 