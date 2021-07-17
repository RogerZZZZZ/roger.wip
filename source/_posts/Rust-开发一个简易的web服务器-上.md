---
title: Rust 开发一个简易的web服务器
date: 2021-07-11 23:04:32
tags:
  - rust
categories:
  - rust
---

## 0. 前言

本章的目的呢是创建一个简单的web服务器, 本文的内容大部分来自于`<<Rust权威指南>>`.

<!-- more -->
## 1. 开始

首先呢, 我们知道一个服务是启动在某一个端口上的, 那我们如何使用rust来创建一个服务监听某一个固定的端口呢. 这里我们使用到的就是`std::net::TcpListener`

```rust
use std::{io::Read, net::{TcpListener, TcpStream}};

fn handle_stream(mut stream: TcpStream) {
	let mut buffer = [0; 512];

  // 读取数据存储到缓冲区中
	stream.read(&mut buffer).unwrap();

  // lossy标识会用 � 来代替无效字符
	println!("Request: {}", String::from_utf8_lossy(&buffer[..]));
}

fn main() {
  // 创建一个监听7878端口的服务.
	let listener = TcpListener::bind("127.0.0.1:7878").unwrap();

	for stream in listener.incoming() {
		let stream = stream.unwrap();

		println!("connection established");

		handle_stream(stream);
	}
}

```

当我们执行`curl 127.0.0.1:7878`, 会收到以下的返回告知我们服务器并没有对此请求作出任何的返回. 所以接下来我们要补充请求的返回

```bash
curl: (52) Empty reply from server
```

### 返回一个HTML

```html
<!-- index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Document</title>
</head>
<body>
  <h1>Hello World</h1>
</body>
</html>
```

```rust
fn handle_stream(mut stream: TcpStream) {
	let mut buffer = [0; 512];

	stream.read(&mut buffer).unwrap();

  // 读取文件
	let content = fs::read_to_string("index.html").unwrap();
	let response = format!("HTTP/1.1 200 OK\r\n\r\n{}", content);
	stream.write(response.as_bytes()).unwrap();
	stream.flush().unwrap();
}
```

这样我们可以通过访问`127.0.0.1:7878`看到一个完整的html渲染结果.

### 如果处理不同的http请求类型

```rust
// 此处以get请求为例

let get = b"GET HTTP/1.1\r\n";

if buffer.startWith(get) {
  // ....
} else {
  // ...
}
```

### 重构一部分代码

```rust
fn handle_stream(mut stream: TcpStream) {
  // ...

  let ( status, filename ) = if (buffer.starts_with(get)) {
    ("HTTP/1.1 200 OK\r\n\r\n", "index.html")
  } else  {
    ("HTTP/1.1 404 NOT FOUND\r\n\r\n", "404.html")
  };

  let content = fs::read_to_string(filename).unwrap();
  let response = format!("{}{}", status, content);
	stream.write(response.as_bytes()).unwrap();
	stream.flush().unwrap();
}
```
