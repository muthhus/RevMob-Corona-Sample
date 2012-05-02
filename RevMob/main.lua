-- Dear Corona Developers,
-- Here is a demo app for RevMob.
-- Please follow the instructions below to
-- successfully integrate RevMob on your app.
--
-- 1. Do not make any changes to the bcfads.lua file.
-- 2. Include the bcfads.lua and the json.lua in your application.
-- 3. Call the show pop-up function in the .lua of your choice.
-- 4. Replace my IDs by yours.
-- You can get IDs registering in our website (www.revmob.com).
-- 5. Test on your iOS device (it won't work in the simulator).
-- 6. Check the results in our website.


require( "bcfads" )

local background = display.newImage( "world.jpg" )

local myText = display.newText( "Meet RevMob!", 0, 0, native.systemFont, 40 )
myText.x = display.contentWidth / 2
myText.y = display.contentWidth / 4
myText:setTextColor( 255,110,110 )

bcfads.showPopup ( { ["Android"] = "4f9ef464f50428000c00000b", ["iPhone OS"] = "4f9ef46d05dfdf000b000008" } )

