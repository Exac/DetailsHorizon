--
-- DetailsHorizon.toc
--
-- Entrypoint is in function DetailsHorizon:OnInitialize()
-- at the bottom of this file.
--
-- This addon creates a horizontal bar that displays
-- player's DPS/Healing in a minimal fashion.
--

-- Create addon using the Ace library.
DetailsHorizon = LibStub("AceAddon-3.0"):NewAddon("DetailsHorizon", "AceEvent-3.0", "AceTimer-3.0")

-- Load libraries.
local Console = LibStub("AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local LibSharedMedia = LibStub("LibSharedMedia-3.0")

-- Database defaults
local defaults = {
    profile = {
        attribute = DETAILS_ATTRIBUTE_DAMAGE,
        subattribute = DETAILS_SUBATTRIBUTE_DPS,
        background = {
            alignment = "BOTTOM", -- TOP | BOTTOM | CENTER
            color = {
                alpha = 1.0,
                blue = 0.125,
                green = 0.125,
                red = 0.125,
            },
            height = 20,
            offset = {
                x = 0,
                y = 0
            },
            texture = "Blizzard",
            isTextureEnabled = false,
        },
        bars = {
            color = {
                alpha = 1.0,
                blue = 1.0,
                green = 1.0,
                red = 1.0,
            },
            texture = "Blizzard",
            -- isCustomColor
            -- false = "class"
            -- true = "color"
            -- nil = "texture"
            isCustomColor = "class",
            count = 10,
            width = 272, -- 16 * 17
            padding = 1,
            text = {
                color = {
                    red = 1.0,
                    green = 1.0,
                    blue = 1.0,
                    alpha = 1.0
                },
                innerPadding = 5,
                size = 16,
                font = "Fonts\\FRIZQT__.TTF",
                style = "OUTLINE, MONOCHROME", -- "OUTLINE, MONOCHROME"
                shadow = 1,
                justifyH = "CENTER", -- CENTER, LEFT, RIGHT
                truncate = true,
                fmt = "%n [%t]" -- %n=name, %t=total, %s=total/time
            },
        },
        switches = {
            isRelative = true,
            isTextUsingClassColor = true,
            isVerbose = false,
            isShowPlayerRealmName = false,
        },
        presets = {
            selected = "avalance"
        }
    }
}

-- Blizzard global functions
local CreateFrame = CreateFrame

-- GUI Frame
local frameParent = CreateFrame("Frame", nil, UIParent)

-- Familiar console logging function
local console = {
    log = function (argument)
        -- Only log if in verbose mode
        if DetailsHorizon:IsVerbose() then
            if argument == nil then argument = "nil" end
            if type(argument)=="boolean" then
                if argument then argument = "true" else argument = "false" end
            end
            Console:Print(ChatFrame1, "|cFFFFFF00[DetailsHorizon]: "..argument);
        end
    end
}

-- Returns true if in verbose mode, else false.
function DetailsHorizon:IsVerbose()
    return self.db.profile.switches.isVerbose
end

-- Only create the UI Elements for child frames. This
-- function can be run MORE THAN ONCE, to add more
-- child frames.
function DetailsHorizon:SetupChildFrames()
    console.log("SetupChildFrames()")
    -- Check if children exist yet
    if not frameParent.children then frameParent.children = {} end

    -- Find out how many children we need to create.
    local currentChildCount = 0
    for _ in pairs(frameParent.children) do currentChildCount = currentChildCount + 1 end
    -- Find how many children we want.
    local desiredChildCount = self.db.profile.bars.count

    -- Find how many children we need to create now.
    local createChildCount = desiredChildCount - currentChildCount
    
    -- If we already have more than the desired number of
    -- children, don't create any more.
    if createChildCount < 0 then createChildCount = 0 end

    -- Add child frames to the parent frame
    for i = createChildCount, 1, -1 do
        local childFrame = CreateFrame("Frame", nil, frameParent)
        
        -- Create texture
        local childFrametexture = childFrame:CreateTexture("BACKGROUND")
        childFrame.texture = childFrametexture
        
        -- Create label
        local childFrameText = childFrame:CreateFontString("childFrameString" .. i, "OVERLAY")
        childFrame.text = childFrameText
        childFrame.text:SetFont(self.db.profile.bars.text.font, self.db.profile.bars.text.size, self.db.profile.bars.text.style) -- font required

        -- Add frame to parent's children
        table.insert(frameParent.children, childFrame)

        -- Display frame
        childFrame:Show()
    end

    console.log("SetupChildFrames() Added "..createChildCount.." unstyled frames to frameparent.children.")
end

-- Only create the UI elements for frameParent. This should
-- only be run once.
function DetailsHorizon:SetupParentFrame()
    -- Add texture to frame
    local t = frameParent:CreateTexture("BACKGROUND")
    t:SetAllPoints(frameParent)
    frameParent.texture = t
    
    -- Add Children to frame
    DetailsHorizon:SetupChildFrames()

    -- Display the frame
    frameParent:Show()

    -- If the scale ever changes, resize the frame then
    DetailsHorizon:RegisterEvent("UI_SCALE_CHANGED", function () DetailsHorizon:OnFrameResize() end)

    console.log("SetupParentFrame() Created unstyled frameParent.")
end

-- Do all the styling for the child frames
function DetailsHorizon:StyleChildFrames()
    console.log("StyleChildFrames()")
    -- First, move all children off-screen incase the
    -- childframe count has been decreased we don't
    -- want old frames sitting around.
    for _, c in ipairs(frameParent.children) do
        c:ClearAllPoints()
        c:SetWidth(0)
        c:SetHeight(0)
        c:SetPoint("LEFT", 0, 0)
        c:ClearAllPoints()
    end

    -- How many bars do we show?
    local count = self.db.profile.bars.count

    -- Width of frame
    local width = self.db.profile.bars.width * 1 / frameParent:GetEffectiveScale()
    
    -- Height of frame (same as parent height)
    local height = self.db.profile.background.height * 1 / frameParent:GetEffectiveScale()
    
    -- Horizontal padding between bars
    local padding = self.db.profile.bars.padding * 1 / frameParent:GetEffectiveScale()

    -- Loop through each bar and build it
    for i,c in ipairs(frameParent.children) do -- i=index, c = child frame
        -- Don't consider extra frames
        if i > count then return end
        
        -- Reset child frame's position
        c:ClearAllPoints()

        -- Dimensions
        c:SetHeight(height)
        c:SetWidth(width - padding)

        -- Background color/texture for the player's frames
        local bgRed = self.db.profile.bars.color.red
        local bgGreen = self.db.profile.bars.color.green
        local bgBlue = self.db.profile.bars.color.blue
        local bgAlpha = self.db.profile.bars.color.alpha
        if self.db.profile.bars.isCustomColor == "texture" then
            -- use texture
            local textureName = self.db.profile.bars.texture
            local texturePath = LibSharedMedia:Fetch("statusbar", textureName)
            c.texture:SetTexture(texturePath)
            c.texture:SetVertexColor(bgRed, bgGreen, bgBlue,bgAlpha)
        elseif self.db.profile.bars.isCustomColor == "color" then
            -- Use colors, no texture
            c.texture:SetColorTexture(bgRed, bgGreen, bgBlue, bgAlpha)
            c.texture:SetVertexColor(bgRed, bgGreen, bgBlue,bgAlpha)
        else
            -- Use class color, which we don't have yet.
            c.texture:SetColorTexture(0.2, 1.0, 0.2, 1.0)
            c.texture:SetVertexColor(bgRed, bgGreen, bgBlue,bgAlpha)
        end
        c.texture:SetAllPoints(c)

        -- Temporarily set a point for the child frame
        c:SetPoint("LEFT", (width * i) - width, 0)

        -- Display the child frame
        c:Show()

        -- Label
        local font = self.db.profile.bars.text.font
        local fontSize = self.db.profile.bars.text.size
        local fontStyle = self.db.profile.bars.text.style
        local fontShadow = self.db.profile.bars.text.shadow
        local fontJustifyH = self.db.profile.bars.text.justifyH
        local fontRed = self.db.profile.bars.text.color.red
        local fontGreen = self.db.profile.bars.text.color.green
        local fontBlue = self.db.profile.bars.text.color.blue
        local fontAlpha = self.db.profile.bars.text.color.alpha
        local fmt = self.db.profile.bars.text.fmt
        local text = DetailsHorizon:FormatLabel(fmt, "Unit", "total", "totalPerSecond")
        if self.db.profile.bars.text.truncate then c.text:SetWidth(width) else c.text:SetWidth(0) end
        c.text:SetHeight(fontSize)
        c.text:SetFont(font, fontSize, fontStyle)
        c.text:SetShadowOffset(fontShadow, -1 * fontShadow)
        c.text:SetTextColor(fontRed, fontGreen, fontBlue, fontAlpha)
        c.text:SetText(text)
        c.text:SetJustifyH(fontJustifyH)
        local topPadding = -1 * ( height - ( c.text:GetHeight() ) ) / 2 -- Vertically center text
        local innerLeftPadding = self.db.profile.bars.innerPadding
        c.text:SetPoint("TOPLEFT", c, "TOPLEFT", innerLeftPadding, topPadding)
        c.text:SetNonSpaceWrap(true)
        c.text:Show()
    end
    console.log("StyleChildFrames() Styled "..count.." child frames.")
    
    -- Finally, call update to put the data into the child frames.
    DetailsHorizon:Update(DetailsHorizon:GenerateData())
end

-- Do all the styling of the parent frame
function DetailsHorizon:StyleParentFrame()
    console.log("StyleParentFrame()")
    -- Reset any scaling applied to the frame
    frameParent:ClearAllPoints()

    frameParent:SetFrameStrata("BACKGROUND")
    
    -- Set width to 100% of screen
    DetailsHorizon:OnFrameResize()

    -- Height of frame.
    local h = self.db.profile.background.height
    local bgHeight = h * 1 / frameParent:GetEffectiveScale()
    frameParent:SetHeight(bgHeight)

    -- Background of frame
    local bgRed = self.db.profile.background.color.red
    local bgGreen = self.db.profile.background.color.green
    local bgBlue = self.db.profile.background.color.blue
    local bgAlpha = self.db.profile.background.color.alpha
    if self.db.profile.background.isTextureEnabled then
        -- use texture, not color
        local bgTextureName = self.db.profile.background.texture
        local bgTexturePath = LibSharedMedia:Fetch("statusbar", bgTextureName)
        frameParent.texture:SetTexture(bgTexturePath)
        frameParent.texture:SetVertexColor(bgRed, bgGreen, bgBlue,bgAlpha)
    else
        -- Use colors, no texture
        frameParent.texture:SetVertexColor(1, 1, 1, 1) -- reset vertex color
        frameParent.texture:SetColorTexture(bgRed, bgGreen, bgBlue, bgAlpha)
    end
    frameParent.texture:SetAllPoints(frameParent)

    -- Align the frame
    local bgAlign = self.db.profile.background.alignment
    local bgOffsetX = self.db.profile.background.offset.x
    local bgOffsetY = self.db.profile.background.offset.y
    frameParent:SetPoint(bgAlign, bgOffsetX, bgOffsetY)

    DetailsHorizon:StyleChildFrames()

    DetailsHorizon:Update(DetailsHorizon:GenerateData())
    
    console.log("StyleParentFrame() Styled the frameParent.")
end

-- We want to always keep the meter as wide as the screen,
-- so whenever the UI scale changes, we set the width again
function DetailsHorizon:OnFrameResize()
    -- Set width of main frame to screen's width.
    DetailsHorizon:SetFrameParentMaxWidth()

    -- TODO: Resize the entire frame or the scaling will be
    -- off.
end

-- Set width of frame to 100%
function DetailsHorizon:SetFrameParentMaxWidth()
    frameParent:SetWidth( GetScreenWidth() )
end

-- Is the Details addon loaded?
function DetailsHorizon:IsDetailsEnabled()
    return IsAddOnLoaded("Details")
end

-- Formats numbers eg: 7654321 => 7.7M, 4321 => 4.3k, 987 => 987
function DetailsHorizon:FormatNumber(number)
    local num
    if type(number)=="number" then
        num = number
    else
        num = 0
    end
    local suffix = ""
    if num >= 1000000000000 then
        num = num / 100000000000
        suffix = "T"
    elseif num >= 1000000000 then
        num = num / 100000000
        suffix = "B"
    elseif num >= 1000000 then
        num = num / 100000
        suffix = "M"
    elseif num >= 1000 then
        num = num / 100
        suffix = "k"
    else end
    return string.format("%.1f", num) .. suffix
end

-- Format labels
-- "%n [%t]" => "Name [1.3k]"
function DetailsHorizon:FormatLabel(fmt, unitname, total, tempo)
    local result
    if type(fmt)=="string" then result = fmt else result = "" end
    if unitName == nil then unitName = "" end
    if total == nil then total = 0 end
    if tempo == nil or temp == infT then tempo = 0 end

    -- Replace unit
    result = string.gsub(result, "%%n", unitname)
    result = string.gsub(result, "%%t", total)
    result = string.gsub(result, "%%s", tempo)

    return result
end

-- Display dps visually on the screen horizontally
function DetailsHorizon:Update(data)    
    -- Validate data
    if data == nil then 
        console.log("Error: DetailsHorizon:Update() recieved nil data.")
        return
    end

    -- Local variables
    local isRelative = self.db.profile.switches.isRelative
    local isCustomColor = self.db.profile.bars.isCustomColor
    local isTextUsingClassColor = self.db.profile.switches.isTextUsingClassColor
    local height = self.db.profile.background.height * 1 / UIParent:GetEffectiveScale()
    local width = GetScreenWidth() -- Width of screen
    local padding = self.db.profile.bars.padding * UIParent:GetEffectiveScale() -- Horizontal padding
    local fmt = self.db.profile.bars.text.fmt
    -- Every child frame
    local p = data.players -- Players we have data on
    local subSubTotal = 0 -- Damage we have drawn to the screen already

    -- Loop through the children, and assign a player's data or clear them
    for i, f in ipairs(frameParent.children) do
        if type(p[i]) == "table" then -- Put player's data into frame...
            -- 1. text value
            f.text:SetText(DetailsHorizon:FormatLabel(fmt, p[i].name, DetailsHorizon:FormatNumber(p[i].total), DetailsHorizon:FormatNumber(p[i].total / p[i].tempo)))
            -- f.text:SetText(p[i].name .. " [" .. DetailsHorizon:FormatNumber(p[i].total) .. "]")
            -- Note: The longest possible label is "Wmmmmmmmmmmmm [222.2M]"
            -- 2. text color
            if isTextUsingClassColor then
                f.text:SetTextColor(p[i].color.class.r, p[i].color.bar.g, p[i].color.bar.b, p[i].color.bar.a)
            else
                f.text:SetTextColor(self.db.profile.bars.text.color.red, self.db.profile.bars.text.color.green, self.db.profile.bars.text.color.blue, self.db.profile.bars.text.color.alpha)
            end
            -- 3. bar color
            if isCustomColor == "class" then
                -- use class color
                f.texture:SetVertexColor(1,1,1,1)
                f.texture:SetColorTexture(p[i].color.class.r, p[i].color.bar.g, p[i].color.bar.b, 0.5)
            elseif isCustomColor == "color" then
                -- use default color
                f.texture:SetVertexColor(1,1,1,1)
                f.texture:SetColorTexture(self.db.profile.bars.color.red, self.db.profile.bars.color.green, self.db.profile.bars.color.blue, self.db.profile.bars.color.alpha)
            elseif isCustomColor == "texture" then
                -- use texture, not color
                f.texture:SetTexture(LibSharedMedia:Fetch("statusbar", self.db.profile.bars.texture))
                f.texture:SetVertexColor(p[i].color.class.r, p[i].color.bar.g, p[i].color.bar.b, p[i].color.bar.a)
            end
            -- 4. position
            if isRelative then
                -- Width of the player's bar
                local relativeWidth = (p[i].total / data.subTotal) * width
                -- Player's bar's offset from left side of parent bar
                local offsetLeft = ((subSubTotal / data.subTotal) * width) + ((i - 1) * padding)
                f:SetWidth(relativeWidth - padding)
                f:SetPoint("LEFT", offsetLeft, 0)
                if self.db.profile.bars.text.truncate then f.text:SetWidth(relativeWidth - padding) else f.text:SetWidth(0) end
                f.text:SetJustifyH(self.db.profile.bars.text.justifyH)
            else
                local fontSize = self.db.profile.bars.text.size
                local barWidth = self.db.profile.bars.width * 1 / UIParent:GetEffectiveScale()
                f:SetWidth(barWidth - padding)
                f:SetPoint("LEFT", ((barWidth + padding) * i) - barWidth, 0)
                if self.db.profile.bars.text.truncate then f.text:SetWidth(barWidth - padding) else f.text:SetWidth(0) end
            end -- if isRelative then
            -- 5. text vertical centering
            local topPadding = -1 * ( height - ( f.text:GetHeight() ) ) / 2 -- Vertically center text
            f.text:SetPoint("TOPLEFT", f, "TOPLEFT", self.db.profile.bars.text.innerPadding, topPadding)
            -- increment subSubTotal
            subSubTotal = subSubTotal + p[i].total
        else -- Clear frame...
            -- 1. text value
            f.text:SetText("")
            -- 2. text color
            f.text:SetTextColor(1,1,1,1)
            -- 4. position
            f:SetWidth(100)
            f:SetPoint("LEFT", -width, 0)
        end
    end -- for in children do loop
end -- Update()

-- Generate data variable in the following shape:
-- {
--     attribute: Number Enum, -- DETAILS_ATTRIBUTE_DAMAGE or DETAILS_ATTRIBUTE_HEAL
--     grandTotal: Number, -- Group's total damage/healing
--     subTotal: Number, -- Displayed group member's total damage/healing
--     players {
--         [key:Number]: {
--             name: String, -- Player's name (without server)
--             total: Number, -- Player's damage/healing
--             tempo: Number, -- Seconds player has been in combat
--             color: {
--                 class: { -- Color to use (based on class)
--                     r: Number
--                     g: Number
--                     b: Number
--                 },
--                 bar: { Color to use (based on Details bar color)
--                     r: Number
--                     g: Number
--                     b: Number
--                 }
--             }
--         }
--     }
-- }
function DetailsHorizon:GenerateData()
    -- Damage or healing?
    attribute = self.db.profile.attribute
    subattribute = self.db.profile.subattribute

    -- Max number of players to organize data for.
    local maxCount = self.db.profile.bars.count

    -- create data to return and set defaults
    local data = {}
    data.attribute = attribute
    data.grandTotal = 0
    data.subTotal = 0
    data.players = {}

    -- Exit early if Details addon not enabled
    if not DetailsHorizon:IsDetailsEnabled() then return data end

    -- Load details API, and sort the actors
    local details = _G.Details
    local combat = Details:GetCurrentCombat()
    local actorContainer = combat:GetContainer(attribute)
    actorContainer:SortByKey("total")

    -- Get group's total
    data.grandTotal = combat:GetTotal(attribute, subattribute, true)

    -- Iterate through actors
    local i = 1 -- index for for loop
    for _, actor in actorContainer:ListActors() do
        if i >= maxCount then return data end -- Stop if we have all our data

        -- Filter out non-grouped players and NPCs.
        if (actor:IsPlayer() and actor:IsGroupPlayer()) then
            local player = {}
            if self.db.profile.switches.isShowPlayerRealmName then
                player.name = actor:name()
            else
                player.name = actor:GetOnlyName()
            end
            if type(actor.total)=="number" then
                player.total = actor.total
            else
                console.log("Actor did not have a total, this is indicitive data that isn't parsable right now.")
                player.total = 0
            end
            if type(actor.Tempo)=="number" then
                player.tempo = actor:Tempo() 
            else 
                -- console.log("Actor did not have a Tempo, this is indicitive data that isn't parsable right now.")
                player.tempo = 0
            end
            player.color = {}
            player.color.class = {}
            player.color.bar = {}
            player.color.class.r, player.color.class.g, player.color.class.b = actor:GetClassColor()
            player.color.bar.r, player.color.bar.g, player.color.bar.b = actor:GetBarColor()
            data.players[i] = player
            data.subTotal = data.subTotal + player.total
            i = i + 1 -- increment index
        end
    end -- for in actorContainer

    return data
end

-- AceAddon setting configuration options. These options allow the commandline
-- options to work, and the Menu -> Interface -> AddOns -> DetailsHorizon GUI
-- interface to work.
function DetailsHorizon:GetConfigOptions()
    local configurationOptions = {
        type = "group",
        childGroups = "tab",
        desc = "DetailsHorizon configuration",
        name = "DetailsHorizon configuration",
        args = {
            general = {
                name = "General",
                desc = "Basic options",
                type = "group",
                order = 10,
                args = {
                    attributeHeader = {
                        order = 10,
                        name = "Attribute",
                        type = "header"
                    },
                    attribute = {
                        name = "Select Damage or Healing",
                        desc = "Choose what data DetailsHorizon displays.",
                        order = 11,
                        type = "select",
                        values = {
                            [1]="Damage",
                            [2]="Healing",
                            [3]="|cFFFF0000Energy|r",
                            [4]="|cFFFF0000Misc|r",
                        },
                        set = function(info, value)
                            if type(value)=="number" then
                                self.db.profile.attribute = value
                                -- Reset subattribute to 1
                                self.db.profile.subattribute = 1
                                DetailsHorizon:StyleParentFrame()
                            end
                        end,
                        get = function (value) return self.db.profile.attribute end,
                    },
                    subattribute = {
                        name = "Subattribute",
                        desc = "Only 'Damage Done' and 'Healing Done' are tested, |cFFFF0000untested|r options do not work well or at all.",
                        order = 12,
                        type = "select",
                        values = function ()
                            if self.db.profile.attribute == 1 then
                                return {
                                    [1]="Damage Done",
                                    [2]="|cFFFF0000DPS|r",
                                    [3]="|cFFFF0000Damage Taken|r",
                                    [4]="|cFFFF0000Friendly Fire|r",
                                    [5]="|cFFFF0000Frags|r",
                                    [6]="|cFFFF0000Enemies|r",
                                    [7]="|cFFFF0000Void Zones|r",
                                    [8]="|cFFFF0000By Spells|r",
                                }
                            elseif self.db.profile.attribute == 2 then
                                return {
                                    [1]="Healing Done",
                                    [2]="|cFFFF0000HPS|r",
                                    [3]="|cFFFF0000Overhealing|r",
                                    [4]="|cFFFF0000Healing Taken|r",
                                    [5]="|cFFFF0000Healing Enemy|r",
                                    [6]="|cFFFF0000Healing Prevented|r",
                                    [7]="|cFFFF0000Healing Absorbed|r",
                                }
                            elseif self.db.profile.attribute == 3 then
                                return {
                                    [1]="|cFFFF0000Mana Regeneration|r",
                                    [2]="|cFFFF0000Rage Regeneration|r",
                                    [3]="|cFFFF0000Energy Regeneration|r",
                                    [4]="|cFFFF0000Runic Regeneration|r",
                                    [5]="|cFFFF0000Resources Regeneration|r",
                                    [6]="|cFFFF0000Alternate Power Regeneration|r",
                                }
                            elseif self.db.profile.attribute == 4 then
                                return {
                                    [1]="|cFFFF0000CC Break|r",
                                    [2]="|cFFFF0000Resurection|r",
                                    [3]="|cFFFF0000Interupts|r",
                                    [4]="|cFFFF0000Dispels|r",
                                    [5]="|cFFFF0000Death|r",
                                    [6]="|cFFFF0000Death Cooldown|r",
                                    [7]="|cFFFF0000Buff Uptime|r",
                                    [8]="|cFFFF0000Debuf Uptime|r",
                                }
                            end
                        end,
                        set = function(info, value)
                            if type(value)=="number" then
                                self.db.profile.subattribute = value
                            end
                            DetailsHorizon:StyleParentFrame()
                        end,
                        get = function (value) return self.db.profile.subattribute end,
                    },
                    colorHeader = {
                        order = 20,
                        name = "Coloring",
                        type = "header"
                    },
                    isTextUsingClassColor = {
                        name = "Text use class colors",
                        desc = "If not checked, text will use the default color.",
                        order = 31,
                        type = "toggle",
                        get = function (value) return self.db.profile.switches.isTextUsingClassColor end,
                        set = function (info, value) 
                            self.db.profile.switches.isTextUsingClassColor = value
                        end,
                    },
                    isRelativeHeader = {
                        order = 40,
                        name = "Display Mode",
                        type = "header"
                    },
                    isRelative = {
                        name = "Relative mode",
                        desc = "Player's bar widths are equal to their contribution percentage.",
                        order = 41,
                        type = "toggle",
                        get = function (value)
                            return self.db.profile.switches.isRelative
                        end,
                        set = function (info, value) 
                            self.db.profile.switches.isRelative = value
                        end,
                    },
                    isShowPlayerRealmName = {
                        name = "Show player's realms",
                        desc = "Show player's realms in cross-realm groups.\nEG: Exac - Bleeding Hollow vs Exac",
                        order = 42,
                        type = "toggle",
                        get = function (value)
                            return self.db.profile.switches.isShowPlayerRealmName
                        end,
                        set = function (info, value) 
                            self.db.profile.switches.isShowPlayerRealmName = value
                        end,
                    },
                    countHeader = {
                        order = 50,
                        type = "header",
                        name = "Player Count",
                    },
                    count = {
                        order = 51,
                        type = "range",
                        name = "Number of Players",
                        desc = "Max number of players RecountHorizon shows at once.\nSet this up to 40 players manually.",
                        min = 10,
                        max = 40,
                        softMin = 10,
                        softMax = 16,
                        step = 1,
                        get = function (value) return self.db.profile.bars.count end,
                        set = function (info, value) 
                            self.db.profile.bars.count = value
                            DetailsHorizon:StyleChildFrames()
                            return value
                        end,
                    },
                    developmentHeader = {
                        order = 60,
                        name = "Developer Settings",
                        type = "header"
                    },
                    isVerbose = {
                        name = "Verbose logging mode",
                        desc = "This is for development. \nIf you enable this you will see messages in your chat from this addon.",
                        order = 61,
                        type = "toggle",
                        get = function (value)
                            return self.db.profile.switches.isVerbose
                        end,
                        set = function (info, value)
                            self.db.profile.switches.isVerbose = value
                        end,
                    },
                },
            },
            bars = {
                name = "Player Totals",
                desc = "Configure how the individual player's totals are displayed",
                order = 30,
                type = "group",
                args = {
                    colorDescription = {
                        order = 7,
                        type = "header",
                        name = "Background Color or Texture",
                    },
                    colorHeader = {
                        order = 9,
                        type = "description",
                        name = "Use class color by default. You may choose a color or texture instead.",
                    },
                    isBarCustomColor = {
                        order = 11,
                        type = "toggle",
                        name = "Use custom color",
                        desc = "Checked = Custom color.\nEmpty = Class Color.\nDisabled = Texture.",
                        tristate = true,
                        get = function(value)
                            -- false = "class"
                            -- true = "color"
                            -- nil = "texture"
                            if self.db.profile.bars.isCustomColor == "class" then return false end
                            if self.db.profile.bars.isCustomColor == "color" then return true end
                            if self.db.profile.bars.isCustomColor == "texture" then return nil end
                        end,
                        set = function (info, value)
                            if value == false then self.db.profile.bars.isCustomColor = "class" end
                            if value == true then self.db.profile.bars.isCustomColor = "color" end
                            if type(value) == "nil" then self.db.profile.bars.isCustomColor = "texture" end
                            DetailsHorizon:StyleChildFrames()
                            return self.db.profile.bars.isCustomColor
                        end,
                    },
                    colorCurrentSelection = {
                        order = 15,
                        type = "description",
                        name = function () 
                            if self.db.profile.bars.isCustomColor == false then
                                return "\nUsing class color."
                            elseif self.db.profile.bars.isCustomColor == true then
                                return "\nUsing custom color."
                            else
                                return "\nUsing texture instead."
                            end
                        end,
                    },
                    color = {
                        order = 12,
                        name = "Custom Color",
                        desc = "Choose player's total background colors",
                        type = "color",
                        hasAlpha = true,
                        set = function(info, r, g, b, a)
                            if r >= 0 and r <= 1 then self.db.profile.bars.color.red = r end
                            if g >= 0 and g <= 1 then self.db.profile.bars.color.green = g end
                            if b >= 0 and b <= 1 then self.db.profile.bars.color.blue = b end
                            if a >= 0 and a <= 1 then self.db.profile.bars.color.alpha = a end
                            -- Update texture & return
                            DetailsHorizon:StyleChildFrames()
                            return self.db.profile.bars.color.red, 
                            self.db.profile.bars.color.green,
                            self.db.profile.bars.color.blue,
                            self.db.profile.bars.color.alpha 
                        end,
                        get = function (value)
                            return self.db.profile.bars.color.red, 
                            self.db.profile.bars.color.green,
                            self.db.profile.bars.color.blue,
                            self.db.profile.bars.color.alpha
                        end,
                    },
                    texture = {
                        order = 13,
                        name = "Texture",
                        desc = "Texture of player's bar",
                        type = "select",
                        values = LibSharedMedia:List("statusbar"),
                        set = function(info, value)
                            self.db.profile.bars.texture = LibSharedMedia:List("statusbar")[value]
                            DetailsHorizon:StyleChildFrames()
                        end,
                        get = function(value)
                            local tName = self.db.profile.bars.texture
                            for i, v in ipairs(LibSharedMedia:List("statusbar")) do
                                if tName == v then return i end
                            end
                            return 0 -- Failed to find an index for the stored name
                        end,
                    },
                    widthHeader = {
                        order = 20,
                        type = "header",
                        name = "Positioning",
                    },
                    width = {
                        order = 22,
                        type = "range",
                        name = "Width",
                        desc = "Width of player's total bar in non-relative mode.",
                        min = 10,
                        max = GetScreenWidth(),
                        softMin = 10,
                        softMax = 512,
                        step = 1,
                        get = function (value) return self.db.profile.bars.width end,
                        set = function (info, value) 
                            self.db.profile.bars.width = value
                            DetailsHorizon:StyleChildFrames()
                            return value
                        end,
                    },
                    isRelativeMode = {
                        name = "Use exact width",
                        desc = "This disables relative mode and forces a width for all bar totals.",
                        order = 21,
                        type = "toggle",
                        get = function (value)
                            return not self.db.profile.switches.isRelative
                        end,
                        set = function (info, value) 
                            self.db.profile.switches.isRelative = not value
                        end,
                    },
                    padding = {
                        order = 23,
                        type = "range",
                        name = "Padding",
                        desc = "Padding between player's totals.",
                        min = 0,
                        max = 128,
                        softMin = 0,
                        softMax = 5,
                        step = 0.25,
                        get = function (value) return self.db.profile.bars.padding end,
                        set = function (info, value) 
                            self.db.profile.bars.padding = value
                            DetailsHorizon:StyleChildFrames()
                            return value
                        end,
                    },
                    labelHeader = {
                        order = 30,
                        type = "header",
                        name = "Label",
                    },
                    labelIsCustom = {
                        name = "Use custom color",
                        desc = "By default use class colors for labels.",
                        order = 31,
                        type = "toggle",
                        get = function (value)
                            return not self.db.profile.switches.isTextUsingClassColor
                        end,
                        set = function (info, value) 
                            self.db.profile.switches.isTextUsingClassColor = not value
                        end,
                    },
                    labelColor = {
                        order = 32,
                        name = "Custom Color",
                        desc = "Choose player's total colors",
                        type = "color",
                        hasAlpha = true,
                        set = function(info, r, g, b, a)
                            if r >= 0 and r <= 1 then self.db.profile.bars.text.color.red = r end
                            if g >= 0 and g <= 1 then self.db.profile.bars.text.color.green = g end
                            if b >= 0 and b <= 1 then self.db.profile.bars.text.color.blue = b end
                            if a >= 0 and a <= 1 then self.db.profile.bars.text.color.alpha = a end
                            -- Update texture & return
                            DetailsHorizon:StyleChildFrames()
                            return self.db.profile.bars.text.color.red, 
                            self.db.profile.bars.text.color.green,
                            self.db.profile.bars.text.color.blue,
                            self.db.profile.bars.text.color.alpha 
                        end,
                        get = function (value)
                            return self.db.profile.bars.text.color.red, 
                            self.db.profile.bars.text.color.green,
                            self.db.profile.bars.text.color.blue,
                            self.db.profile.bars.text.color.alpha
                        end,
                    },
                    labelInnerPadding = {
                        order = 59,
                        type = "range",
                        name = "Left Padding",
                        desc = "Inner left padding between the text and the left of the frame.",
                        min = 0,
                        max = 128,
                        softMin = 0,
                        softMax = 16,
                        step = 1,
                        get = function (value) return self.db.profile.bars.text.innerPadding end,
                        set = function (info, value) 
                            self.db.profile.bars.text.innerPadding = value
                            DetailsHorizon:StyleChildFrames()
                            return value
                        end,
                    },
                    labelFontSize = {
                        order = 54,
                        type = "range",
                        name = "Font Size",
                        desc = "Font size.",
                        min = 6,
                        max = 72,
                        softMin = 8,
                        softMax = 32,
                        step = 1,
                        get = function (value) return self.db.profile.bars.text.size end,
                        set = function (info, value) 
                            self.db.profile.bars.text.size = value
                            DetailsHorizon:StyleChildFrames()
                            return value
                        end,
                    },
                    labelFont = {
                        order = 55,
                        name = "Font",
                        desc = "Font of player's bar",
                        type = "select",
                        values = function ()
                            local hashTable = LibSharedMedia:HashTable("font")
                            local invertedHastTable = {}
                            for k,v in pairs(hashTable) do
                                invertedHastTable[v]=k
                            end
                            return invertedHastTable
                        end,
                        set = function(info, value)
                            self.db.profile.bars.text.font = value
                            DetailsHorizon:StyleChildFrames()
                        end,
                        get = function(value)
                            return self.db.profile.bars.text.font
                        end,
                    },
                    labelFontStyle = {
                        name = "Font Style",
                        desc = "Choose font style(s).\nMonochrome is for blocky pixel-fonts.",
                        order = 56,
                        type = "select",
                        values = {
                            [1]="None",
                            [2]="Outline",
                            [3]="Monochrome",
                            [4]="Outline & Monochrome",
                        },
                        get = function (value)
                            local o = string.find(self.db.profile.bars.text.style, "OUTLINE")
                            local m = string.find(self.db.profile.bars.text.style, "MONOCHROME")

                            if (type(o)=="nil" and type(m)=="nil") then
                                return 1 -- none
                            elseif (type(o)=="number" and type(m)=="nil") then
                                return 2 -- outline
                            elseif (type(o)=="nil" and type(m)=="number") then
                                return 3 -- monochrome
                            elseif (type(o)=="number" and type(m)=="number") then
                                return 4 -- outline & monochrome
                            else
                                console.log("Error: Unexpected o or m value.")
                            end
                        end,
                        set = function (info, value)
                            if value == 1 then
                                self.db.profile.bars.text.style = ""
                            elseif value == 2 then
                                self.db.profile.bars.text.style = "OUTLINE"
                            elseif value == 3 then
                                self.db.profile.bars.text.style = "MONOCHROME"
                            elseif value == 4 then
                                self.db.profile.bars.text.style = "OUTLINE, MONOCHROME"
                            end
                            DetailsHorizon:StyleChildFrames()
                        end,
                    },
                    labelFontShadow = {
                        order = 59,
                        type = "range",
                        name = "Shadow length",
                        desc = "Set to 0 to hide shadow. Max 10.",
                        min = 0,
                        max = 10,
                        softMin = 0,
                        softMax = 3,
                        step = 0.5,
                        get = function (value)
                            return self.db.profile.bars.text.shadow
                        end,
                        set = function (info, value)
                            self.db.profile.bars.text.shadow = value
                            DetailsHorizon:StyleChildFrames()
                            return value
                        end,
                    },
                    labelFontJustifyH = {
                        order = 57,
                        type = "select",
                        name = "Alignment",
                        values = {
                            ["CENTER"]="Center",
                            ["LEFT"]="Left",
                            ["RIGHT"]="Right",
                        },
                        get = function (value)
                            return self.db.profile.bars.text.justifyH
                        end,
                        set = function (info, value)
                            self.db.profile.bars.text.justifyH = value
                            DetailsHorizon:StyleChildFrames()
                            return value
                        end,
                    },
                    labelIsTruncated = {
                        order = 59,
                        type = "toggle",
                        name = "Truncate text",
                        desc = "If you disable this, text can overflow the "
                        .."frame to the right, and text may overlap.",
                        set = function (info, value)
                            console.log(value)
                            self.db.profile.bars.text.truncate = value
                            DetailsHorizon:Update(DetailsHorizon:GenerateData())
                            DetailsHorizon:StyleParentFrame()
                            return value
                        end,
                        get = function (value)
                            return self.db.profile.bars.text.truncate
                        end,
                    },
                    formatHeader = {
                        order = 70,
                        type = "header",
                        name = "Text Format"
                    },
                    formatDescription = {
                        order = 71,
                        type = "description",
                        name = "You may customize how damage is shown for "
                        .."each player. Add these variables into your format "
                        .."string to display the data:\n|cFFFFFF00%n|r = "
                        .."Character's name    |cFFFFFF00%t|r = Character's "
                        .."total    |cFFFFFF00%s|r = Character's total / "
                        .."combat time\n\n'%n [%t]' = '"..UnitName("player")
                        .." [123.4k]'",
                    },
                    formatString = {
                        order = 73,
                        type = "input",
                        name = "Format",
                        multiline = false,
                        get = function (value) return self.db.profile.bars.text.fmt end,
                        set = function (info, value)
                            self.db.profile.bars.text.fmt = value
                            return value
                        end,
                    },
                },
            },
            background = {
                name = "Background",
                desc = "Configure the meter's background appearance.",
                order = 40,
                type = "group",
                args = {
                    alignmentDescription = {
                        order = 31,
                        type = "header",
                        name = "Positioning",
                    },
                    alignment = {
                        order = 32,
                        name = "Alignment",
                        desc = "How to align the addon on the screen",
                        type = "select",
                        values = { ["TOP"]="TOP", ["BOTTOM"]="BOTTOM", ["CENTER"]="CENTER" },
                        set = function(info, value)
                            self.db.profile.background.alignment = value
                            DetailsHorizon:StyleParentFrame()
                        end,
                        get = function (value) return self.db.profile.background.alignment end,
                    },
                    colorHeader = {
                        order = 10,
                        type = "header",
                        name = "Color",
                    },
                    colorDescription = {
                        order = 9,
                        name = "This only changes the background, the forground bars have their own colors.",
                        type = "description"
                    },
                    color = {
                        order = 11,
                        name = "Color",
                        desc = "Choose a main background color",
                        type = "color",
                        hasAlpha = true,
                        set = function(info, r, g, b, a)
                            if r >= 0 and r <= 1 then self.db.profile.background.color.red = r end
                            if g >= 0 and g <= 1 then self.db.profile.background.color.green = g end
                            if b >= 0 and b <= 1 then self.db.profile.background.color.blue = b end
                            if a >= 0 and a <= 1 then self.db.profile.background.color.alpha = a end
                            -- Update texture & return
                            DetailsHorizon:StyleParentFrame()
                            return self.db.profile.background.color.red, 
                            self.db.profile.background.color.green,
                            self.db.profile.background.color.blue,
                            self.db.profile.background.color.alpha 
                        end,
                        get = function (value)
                            return self.db.profile.background.color.red, 
                            self.db.profile.background.color.green,
                            self.db.profile.background.color.blue,
                            self.db.profile.background.color.alpha
                        end,
                    },
                    textureHeader = {
                        order = 13,
                        type = "header",
                        name = "Texture",
                    },
                    isTextureEnabled = {
                        order = 14,
                        type = "toggle",
                        name = "Use texture",
                        desc = "Use a texture instead of a flat color.",
                        set = function (info, value)
                            self.db.profile.background.isTextureEnabled = value
                            DetailsHorizon:StyleParentFrame()
                        end,
                        get = function (value) return self.db.profile.background.isTextureEnabled end,
                    },
                    texture = {
                        order = 15,
                        name = "Texture",
                        desc = "Texture of empty space on bar.",
                        type = "select",
                        values = LibSharedMedia:List("statusbar"),
                        set = function(info, value)
                            self.db.profile.background.texture = LibSharedMedia:List("statusbar")[value]
                            console.log("setting texture to "..LibSharedMedia:List("statusbar")[value])
                            DetailsHorizon:StyleParentFrame()
                        end,
                        get = function(value)
                            local tName = self.db.profile.background.texture
                            for i, v in ipairs(LibSharedMedia:List("statusbar")) do
                                if tName == v then
                                    console.log("get() tName="..self.db.profile.background.texture..", v="..v..", i="..i)
                                    return i
                                end
                            end
                            return 0 -- Failed to find an index for the stored name
                        end,
                    },
                    height = {
                        order = 41,
                        name = "Height",
                        desc = "How tall is the meter?",
                        type = "range",
                        min = 8,
                        max = 128,
                        step = 1,
                        bigStep = 2,
                        isPercent = false,
                        set = function(info, value)
                            self.db.profile.background.height = value
                            DetailsHorizon:StyleParentFrame()
                            return value
                        end,
                        get = function (value)
                            return self.db.profile.background.height
                        end,
                    },
                    offsetHeader = {
                        order = 51,
                        type = "header",
                        name = "Offset",
                    },
                    offsetX = {
                        name = "Horizontal",
                        desc = "Move the entire addon left (negative) or right(positive). \nYou must manually enter a number to change this. \nThis should almost always be 0.",
                        order = 52,
                        type = "range",
                        min = math.ceil(-1 * GetScreenWidth()),
                        max = math.ceil(GetScreenWidth()),
                        softMin = 0,
                        softMax = 0,
                        isPercent = false,
                        get = function(value)
                            return self.db.profile.background.offset.x
                        end,
                        set = function(info, value)
                            self.db.profile.background.offset.x = value
                            DetailsHorizon:StyleParentFrame()
                        end,
                    },
                    offsetY = {
                        name = "Vertical",
                        desc = "Move the entire addon up (negative) or down (positive).",
                        order = 53,
                        type = "range",
                        min = math.ceil((-1 * GetScreenHeight() / 2) - 16),
                        max = math.ceil((GetScreenHeight() / 2) + 16),
                        isPercent = false,
                        get = function(value)
                            return self.db.profile.background.offset.y
                        end,
                        set = function(info, value)
                            self.db.profile.background.offset.y = value
                            DetailsHorizon:StyleParentFrame()
                        end,
                    },
                },
            },
            presets = {
                name = "Presets",
                desc = "Choose from pre-built styles.",
                order = 51,
                type = "group",
                args = {
                    list = {
                        order = 1,
                        type = "select",
                        name = "Presets",
                        desc = "Choose a style",
                        values = {
                            ["recount"]="Recount",
                            ["avalanche"]="Avalanche",
                            ["monokai"]="Monokai",
                            ["darcula"]="Darcula",
                            ["storm"]="Storm",
                            ["forcedsquare"]="Forced Square",
                        },
                        set = function (info, value)
                            self.db.profile.presets.selected = value
                            return value
                        end,
                        get = function (value)
                            return self.db.profile.presets.selected
                        end,
                    },
                    apply ={
                        order = 2,
                        type = "execute",
                        name = "Apply Preset",
                        desc = function () return "Click to use the "..self.db.profile.presets.selected.." preset." end,
                        func = function ()
                            local preset = self.db.profile.presets.selected
                            if preset == "avalanche" then
                                self.db.profile.background.alignment = "BOTTOM"
                                self.db.profile.background.color.alpha = 1
                                self.db.profile.background.color.blue = 1
                                self.db.profile.background.color.green = 1
                                self.db.profile.background.color.red = 1
                                self.db.profile.background.height = 20
                                self.db.profile.background.offset.x = 0
                                self.db.profile.background.offset.y = 0
                                self.db.profile.background.isTextureEnabled = false
                                self.db.profile.bars.color.alpha = 1
                                self.db.profile.bars.color.blue = 1
                                self.db.profile.bars.color.green = 1
                                self.db.profile.bars.color.red = 1
                                self.db.profile.bars.isCustomColor = "color"
                                self.db.profile.bars.count = 10
                                self.db.profile.bars.width = 123
                                self.db.profile.bars.padding = 0
                                self.db.profile.bars.text.color.alpha = 1
                                self.db.profile.bars.text.color.red = 0
                                self.db.profile.bars.text.color.green = 0
                                self.db.profile.bars.text.color.blue = 0
                                self.db.profile.bars.text.innerPadding = 1
                                self.db.profile.bars.text.size = 14
                                self.db.profile.bars.text.font = "Interface\\AddOns\\Details\\Fonts\\Oswald-Regular.otf"
                                self.db.profile.bars.text.style = ""
                                self.db.profile.bars.text.shadow = 0
                                self.db.profile.bars.text.justifyH = "CENTER"
                                self.db.profile.switches.isRelative = false
                                self.db.profile.switches.isTextUsingClassColor = false
                            elseif preset == "monokai" then
                                self.db.profile.background.alignment = "BOTTOM"
                                self.db.profile.background.color.alpha = 1
                                self.db.profile.background.color.red = 0.17
                                self.db.profile.background.color.green = 0.16
                                self.db.profile.background.color.blue = 0.18
                                self.db.profile.background.height = 20
                                self.db.profile.background.offset.x = 0
                                self.db.profile.background.offset.y = 0
                                self.db.profile.background.isTextureEnabled = false
                                self.db.profile.bars.color.alpha = 1
                                self.db.profile.bars.color.red = 0.29
                                self.db.profile.bars.color.green = 0.28
                                self.db.profile.bars.color.blue = 0.24
                                self.db.profile.bars.isCustomColor = "color"
                                self.db.profile.bars.count = 10
                                self.db.profile.bars.width = 123
                                self.db.profile.bars.padding = 1
                                self.db.profile.bars.text.color.alpha = 1
                                self.db.profile.bars.text.color.red = 0.99
                                self.db.profile.bars.text.color.green = 0.99
                                self.db.profile.bars.text.color.blue = 0.98
                                self.db.profile.bars.text.innerPadding = 1
                                self.db.profile.bars.text.size = 14
                                self.db.profile.bars.text.font = "Interface\\AddOns\\DetailsHorizon\\Media\\Fonts\\FiraMono-Medium.ttf"
                                self.db.profile.bars.text.style = ""
                                self.db.profile.bars.text.shadow = 0
                                self.db.profile.bars.text.justifyH = "CENTER"
                                self.db.profile.switches.isRelative = false
                                self.db.profile.switches.isTextUsingClassColor = false
                            elseif preset == "darcula" then
                                self.db.profile.background.alignment = "BOTTOM"
                                self.db.profile.background.color.alpha = 1
                                self.db.profile.background.color.red = 0.16
                                self.db.profile.background.color.green = 0.21
                                self.db.profile.background.color.blue = 0.16
                                self.db.profile.background.height = 20
                                self.db.profile.background.offset.x = 0
                                self.db.profile.background.offset.y = 0
                                self.db.profile.background.isTextureEnabled = false
                                self.db.profile.bars.color.alpha = 1
                                self.db.profile.bars.color.blue = 0.16
                                self.db.profile.bars.color.green = 0.21
                                self.db.profile.bars.color.red = 0.16
                                self.db.profile.bars.isCustomColor = "color"
                                self.db.profile.bars.count = 10
                                self.db.profile.bars.width = 150
                                self.db.profile.bars.padding = 1
                                self.db.profile.bars.text.color.alpha = 1
                                self.db.profile.bars.text.color.red = 0.97
                                self.db.profile.bars.text.color.green = 0.97
                                self.db.profile.bars.text.color.blue = 0.95
                                self.db.profile.bars.text.innerPadding = 1
                                self.db.profile.bars.text.size = 16
                                self.db.profile.bars.text.font = "Interface\\AddOns\\DetailsHorizon\\Media\\Fonts\\FiraMono-Medium.ttf"
                                self.db.profile.bars.text.style = ""
                                self.db.profile.bars.text.shadow = 0
                                self.db.profile.bars.text.justifyH = "CENTER"
                                self.db.profile.switches.isRelative = true
                                self.db.profile.switches.isTextUsingClassColor = false
                            elseif preset == "recount" then
                                self.db.profile.background.alignment = "BOTTOM"
                                self.db.profile.background.color.alpha = 0.5
                                self.db.profile.background.color.red = 0
                                self.db.profile.background.color.green = 0
                                self.db.profile.background.color.blue = 0
                                self.db.profile.background.height = 12
                                self.db.profile.background.offset.x = 0
                                self.db.profile.background.offset.y = 1
                                self.db.profile.background.texture = "Details Flat"
                                self.db.profile.background.isTextureEnabled = false
                                self.db.profile.bars.color.alpha = 1
                                self.db.profile.bars.isCustomColor = "texture"
                                self.db.profile.bars.texture = "Details Serenity"
                                self.db.profile.bars.count = 10
                                self.db.profile.bars.width = 150
                                self.db.profile.bars.padding = 1
                                self.db.profile.bars.text.color.alpha = 1
                                self.db.profile.bars.text.color.red = 0.97
                                self.db.profile.bars.text.color.green = 0.97
                                self.db.profile.bars.text.color.blue = 0.95
                                self.db.profile.bars.text.innerPadding = 3
                                self.db.profile.bars.text.size = 12
                                self.db.profile.bars.text.font = "Fonts\\ARIALN.ttf"
                                self.db.profile.bars.text.style = ""
                                self.db.profile.bars.text.shadow = 1
                                self.db.profile.bars.text.justifyH = "LEFT"
                                self.db.profile.switches.isRelative = true
                                self.db.profile.switches.isTextUsingClassColor = false
                            elseif preset == "storm" then
                                self.db.profile.background.alignment = "BOTTOM"
                                self.db.profile.background.color.alpha = 0.75
                                self.db.profile.background.color.red = 0.16
                                self.db.profile.background.color.green = 0.16
                                self.db.profile.background.color.blue = 0.16
                                self.db.profile.background.height = 18
                                self.db.profile.background.offset.x = 0
                                self.db.profile.background.offset.y = 0
                                self.db.profile.background.texture = "Details Flat"
                                self.db.profile.background.isTextureEnabled = false
                                self.db.profile.bars.color.alpha = 0
                                self.db.profile.bars.color.red = 0.16
                                self.db.profile.bars.color.green = 0.16
                                self.db.profile.bars.color.blue = 0.16
                                self.db.profile.bars.isCustomColor = "color"
                                self.db.profile.bars.texture = "Details Serenity"
                                self.db.profile.bars.count = 10
                                self.db.profile.bars.width = 150
                                self.db.profile.bars.padding = 1
                                self.db.profile.bars.text.color.alpha = 1
                                self.db.profile.bars.text.color.red = 1
                                self.db.profile.bars.text.color.green = 1
                                self.db.profile.bars.text.color.blue = 1
                                self.db.profile.bars.text.innerPadding = 3
                                self.db.profile.bars.text.size = 12
                                self.db.profile.bars.text.font = "Interface\\AddOns\\Details\\Fonts\\Oswald-Regular.otf"
                                self.db.profile.bars.text.style = ""
                                self.db.profile.bars.text.shadow = 1
                                self.db.profile.bars.text.justifyH = "CENTER"
                                self.db.profile.switches.isRelative = false
                                self.db.profile.switches.isTextUsingClassColor = true
                            elseif preset == "forcedsquare" then
                                self.db.profile.background.alignment = "BOTTOM"
                                self.db.profile.background.color.alpha = 0.75
                                self.db.profile.background.color.red = 0
                                self.db.profile.background.color.green = 0
                                self.db.profile.background.color.blue = 0
                                self.db.profile.background.height = 18
                                self.db.profile.background.offset.x = 0
                                self.db.profile.background.offset.y = 0
                                self.db.profile.background.texture = "Details Flat"
                                self.db.profile.background.isTextureEnabled = false
                                self.db.profile.bars.color.alpha = 1
                                self.db.profile.bars.color.red = 0
                                self.db.profile.bars.color.green = 0
                                self.db.profile.bars.color.blue = 0
                                self.db.profile.bars.isCustomColor = "class"
                                self.db.profile.bars.texture = "Blizzard"
                                self.db.profile.bars.count = 10
                                self.db.profile.bars.width = 150
                                self.db.profile.bars.padding = 1
                                self.db.profile.bars.text.color.alpha = 1
                                self.db.profile.bars.text.color.red = 1
                                self.db.profile.bars.text.color.green = 1
                                self.db.profile.bars.text.color.blue = 1
                                self.db.profile.bars.text.innerPadding = 16
                                self.db.profile.bars.text.size = 22 -- Multiple of 11
                                self.db.profile.bars.text.font = "Interface\\AddOns\\Details\\Fonts\\FORCED SQUARE.ttf"
                                self.db.profile.bars.text.style = "OUTLINE, MONOCHROME"
                                self.db.profile.bars.text.shadow = 1
                                self.db.profile.bars.text.justifyH = "LEFT"
                                self.db.profile.switches.isRelative = true
                                self.db.profile.switches.isTextUsingClassColor = false
                            end
                            DetailsHorizon:StyleParentFrame()
                        end
                    }
                },
            }
        },
    }
    return configurationOptions
end

-- Main Loop, this is run over and over.
function DetailsHorizon:Loop()
    -- Display frame with damage
    local data = DetailsHorizon:GenerateData()

    DetailsHorizon:Update(data)
end -- Loop()

-- ENTRY-POINT
function DetailsHorizon:OnInitialize()
    -- get config options for Ace3 AceConfig
    local configOptions = DetailsHorizon:GetConfigOptions()
    
    AceConfig:RegisterOptionsTable("DetailsHorizon", configOptions, {"detailshorizon", "detailsh"})
    
    -- Create a new database object using the default table, and add it to
    -- the game's Interface > AddOns menu.
    self.defaults = defaults
    self.db = AceDB:New("DetailsHorizonDB", self.defaults, true);
    self.profilesFrame = AceConfigDialog:AddToBlizOptions("DetailsHorizon", "DetailsHorizon");

    console.log("OnInitialize()")

    -- Create the parent frame only once. This has the side-effect of creating
    -- the child-frames too. Style the parent & child frames next.
    DetailsHorizon:SetupParentFrame();
    DetailsHorizon:StyleParentFrame();
    DetailsHorizon:StyleChildFrames();

    -- Initialize the main loop that will call Details! and update the
    -- horizontal display.
    self.testTimer = self:ScheduleRepeatingTimer("Loop", 1)
end -- OnInitialize()
