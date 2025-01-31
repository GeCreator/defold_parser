# Defold Parser (lua)
A simple module that allows you to create/parse/modify Defold files(collection/go/atlas, etc.).

#### example

```lua
local parser = require "defold_parser"
local atlas = parser.load("assets/atlas.atlas")
for _, d in ipairs(atlas.images) do
	print(d.image)
	d.sprite_trim_mode = "SPRITE_TRIM_MODE_6"
end
atlas.inner_paddin = 1.0
parser.save("assets/atlas.atlas", atlas)
```
# API

| method                     | return type | description                                                      |
| -------------------------- | ----------- | ---------------------------------------------------------------- |
| parser.load([path])        | table       | parse file result as sorted table                                |
| parser.save([path], [tbl]) | void        | save table to file                                               |
| parser.parse([string])     | table       | parse string to table                                            |
| parser.compile([tbl])      | string      | convert table to string                                          |
| parser.table()             | table       | create and return table that store key order in key based tables |

#### Example 1: create file
`It looks terrible, but it's the right way to create new file. As a result, we will always get the same file at the output.`
```lua
local parser = require "defold_parser"
local atlas = parser.table()

local img1 = parser.table()
img1.image = "/path/to/image1.png",
img1.sprite_trim_mode = "/path/to/image.png"

local img2 = parser.table()
img2.image = "/path/to/image2.png",
img2.sprite_trim_mode = "/path/to/image.png",

atlas.images = {img1, img2}
atlas.margin = 0
atlas.extrude_borders = 2
atlas.inner_padding = 0.5

parser.save("assets/atlas.atlas", atlas)
```
#### Example 2: create file
`Looks nicer, but each time the output will be different. The margin, extrude_borders, inner_padding keys will always move to different places. If stability is important to you(for the version control system), then it is better to use parser.table() instead of regular lua tables`
```lua
local parser = require "defold_parser"
local atlas = {
	{
		image = "/path/to/image.png",
		sprite_trim_mode = "SPRITE_TRIM_MODE_OFF"
	},
	{
		image = "/path/to/image2.png",
		sprite_trim_mode = "SPRITE_TRIM_MODE_OFF"
	},
	margin = 0,
	extrude_borders = 2,
	inner_padding = 0.5
}
parser.save("assets/atlas.atlas", atlas)
```

#### Test
```lua
$ lua test.lua
```
