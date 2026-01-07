local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local wechat = sbar.add("item", "widgets.wechat", {
  position = "right",
  icon = {
    string = "󰘑",  -- NerdFont WeChat icon
    font = {
      family = "Hack Nerd Font",  -- Use SketchyBar's native Hack Nerd Font
      style = settings.font.style_map["Regular"],
      size = 19.0,
    },
    color = colors.green,
  },
  label = {
    string = "",
    font = { family = settings.font.numbers },
    padding_left = 5,
  },
  update_freq = 5,  -- Update every 5 seconds
  padding_right = settings.paddings,
  padding_left = settings.paddings,
})

-- Function to update notification count
local function update_notification_count()
  -- First get WeChat's ASN, then get its StatusLabel
  sbar.exec("lsappinfo list | grep -B1 'com.tencent.xinWeChat' | head -1 | sed -n 's/.*ASN:\\([^ :]*\\).*/\\1/p' | head -1 | xargs -I {} sh -c 'lsappinfo info -only StatusLabel \"ASN:{}\" | grep -o \"\\\"label\\\"=\\\"[^\\\"]*\\\"\" | cut -d= -f2 | tr -d \"\\\"\"'", function(count)
    count = count:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace

    if count ~= "" and tonumber(count) and tonumber(count) > 0 then
      wechat:set({
        label = {
          string = count,
          drawing = true,
        },
        icon = { color = colors.red }  -- Red icon when there are notifications
      })
    else
      wechat:set({
        label = {
          string = "",
          drawing = false,
        },
        icon = { color = colors.green }  -- Green icon when no notifications
      })
    end
  end)
end

-- Subscribe to events to update count
wechat:subscribe({"routine", "forced", "system_woke"}, update_notification_count)

-- Click to open WeChat
wechat:subscribe("mouse.clicked", function(env)
  sbar.exec("open -a WeChat")
end)

-- Background around the wechat item
sbar.add("bracket", "widgets.wechat.bracket", { wechat.name }, {
  background = { color = colors.bg1 }
})

-- Padding after wechat item
sbar.add("item", "widgets.wechat.padding", {
  position = "right",
  width = settings.group_paddings
})
