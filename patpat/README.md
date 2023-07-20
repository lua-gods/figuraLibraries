# patpat
Simple figura lua script that allows to pet people and player heads
you can pet by clicking or holding right mouse buttom (can be configured) while looking at player or player head

## events
all events can be configured for both player and player head
`onPat` runs when you start being petted
`onUnpat` runs when you stop being petted
`togglePat` runs when you start or stop being petted, isPetted - boolean that is true when someone starts
`whilePat` runs every tick while being patted, patters - list of people patting you 
`oncePat` every time someone pats you, entity - entity that is petting you

you can add events by editing `patpat.lua`
or by using `require` function and adding functions to table like this:
```lua
local patpat = require("patpat")
table.insert(patpat.onPat, function() -- if you dont specify if event is for player or player head it will use player as default
  print("someone started petting me")
end)

table.insert(patpat.head.oncePat, function()
  print("someone petted my player head")
end
```

## disable pats
You can disable pats in config at top of file or by adding this line of code in your avatar:
```lua
avatar:store("patpat.noPats", true)
```

or you can just disable particles (also possible to configure in config)
```lua
avatar:store("patpat.noHearts", true)
```

## compatibility
patpat is compatible with both petpet and [slyme patpat](https://github.com/Slymeball/figura-avatars/blob/main/Rewrite/Patpat/Patpat.lua)
