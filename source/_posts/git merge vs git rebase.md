---
title: Git Merging vs. Rebasing
date: 2021-01-08 13:48:15
tags: git
categories: git
---

在日常的工作中, 我已经无数次的使用git命令来管理代码仓库以及管理团队协作的问题. 但是直到今天才彻底搞清合并代码时候使用的`git rebase`以及`git merge`的区别.

![branch.png](https://wac-cdn.atlassian.com/dam/jcr:1523084b-d05a-4f5a-bd1a-01866ec09ca3/01%20A%20forked%20commit%20history.svg?cdnVersion=547)

<!-- more -->

首先我们要知道的是`git rebase`以及`git merge`在达到的最终效果上是没有区别的, 可以说是殊途同归. 那接下来我们来看看两者在过程中的具体差异.


## Merging

当我们需要将开发分支合并到主干或者是预发布分支时, 如果使用merge命令需要切到主干/预发布分支进行操作, 多少感觉是很奇怪的, 而且相比rebase最大的区别是会多一个合并节点.

![merge.png](https://wac-cdn.atlassian.com/dam/jcr:4639eeb8-e417-434a-a3f8-a972277fc66a/02%20Merging%20main%20into%20the%20feature%20branh.svg?cdnVersion=547)

## Rebasing

![rebase.png](https://wac-cdn.atlassian.com/dam/jcr:3bafddf5-fd55-4320-9310-3d28f4fca3af/03%20Rebasing%20the%20feature%20branch%20into%20main.svg?cdnVersion=547)

功能非常的直观, 将rebase分支的commit放于你分支新commit的前面, rebase的流程是逐个commit去检查是否有冲突, 如果有会阻断rebase进程, 待你解决冲突后, `git rebase --continue`继续流程直到结束. 那`rebase`有什么好处呢

- history没有被破坏
- 没有新增多余的commit节点
- 不会破坏主干分支就可以多次更新主干代码

当然在使用的时候需要注意的是: **不要在主干分支进行rebase**, 会影响到别的开发者的协同开发.

## 最佳实践

```sh
git checkout feature
git checkout -b temporary-branch
git rebase -i main
# [Clean up the history]
git checkout main
git merge temporary-branch
```