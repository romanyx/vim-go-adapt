Use [adapt](https://github.com/romanyx/adapt) in Your Vim
=========================================================

![gif](example.gif)

[adapt](https://github.com/romanyx/adapt) is a very handy tool to generate adapters for single method interfaces.
This plugin is created to use [adapt](https://github.com/romanyx) in your Vim.

## Intall

vim-plug:

```
Plug 'romanyx/vim-go-adapt'
```

## Usage

Simply do:

```
:GoAdapt {package} {interface}
```

Or to adapt interface from package you're working on:

```
:GoAdapt {interface}
```

Note that `:Adapt` is also available. It is equivalent to `:GoAdapt`.

## Requirements

- `go` command
- [adapt](https://github.com/romanyx/adapt) command
