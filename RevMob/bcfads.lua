-- BCFAds iPhone Corona SDK - version 0.2 (experimental)
--
-- Usage:
--
--  * Include the library in your project:
--       require "bcfads"
--
--  * To show a pop-up ad (if you are a publisher):
--       bcfads.showPopup({ ["Android"] = "Android App Id", ["iPhone OS"] = "IPhone OS App Id" })
--
--  * To register an application installation (if you are an advertiser):
--       bcfads.registerInstall({ ["Android"] = "Android App Id", ["iPhone OS"] = "IPhone OS App Id" })
--
--  * To use the staging server (staging.bcfads.com) instead of production,
--    call this before actions (e.g., just after 'require "bcfads"):
--     bcfads.setStagingMode(true)
--
-- "your app id" is the one you got at http://www.bcfads.com for your application.
--

--============ Implementation ============--

require "json"

local DEBUG_MODE = false

------ Constants

local STAGING_SERVER_ADDRESS = "staging.bcfads.com"
local PRODUCTION_SERVER_ADDRESS = "api.bcfads.com"
local POPUP_YES_BUTTON_POSITION = 2

------ Helper functions

local function log( message )
  print("BCFAds " .. message)
  io.output():flush()
end

local function urlForAPIPath( path )
  if (bcfads.staging) then
    log("INFO: using staging server")
    server = STAGING_SERVER_ADDRESS
  else
    log("INFO: using production server")
    server = PRODUCTION_SERVER_ADDRESS
  end
  return "https://" .. server .. "/" .. path
end

------ Popup display and click action

local function onPopupButtonClick( event )
  if "clicked" == event.action then
    if POPUP_YES_BUTTON_POSITION == event.index then
      system.openURL(bcfads["link"])
    end
  end
end

local function hasPopup( jsonString )
  status, response = pcall(json.decode, jsonString)
  -- For some reason, short-circuiting did not work, otherwise this could be
  -- a single statement using "and"
  if (not status) then
    return false
  elseif (response == nil) then
    return false
  elseif (response["pop_up"] == nil) then
    return false
  elseif (response["pop_up"]["message"] == nil) then
    return false
  elseif (response["pop_up"]["links"] == nil) then
    return false
  elseif (response["pop_up"]["links"][1] == nil) then
    return false
  elseif (response["pop_up"]["links"][1]["href"] == nil) then
    return false
  end
  return true
end

local function showPopupIfAny( jsonString )
  if (hasPopup(jsonString)) then
    response = json.decode(jsonString)
    message = response["pop_up"]["message"]
    link = response["pop_up"]["links"][1]["href"]
    log("GOT_POPUP: " .. message .. "," .. link)
    bcfads["link"] = link
    local alert = native.showAlert( message, "",
            { "No, thanks.", "Yes, Sure!" }, onPopupButtonClick )
  end
end

------ Network

local function networkListener( event )
  if ( event.isError ) then
    log("ERROR: Network Error")
  else
    log("RESPONSE: " .. event.response )
    showPopupIfAny(event.response)
  end
  if (DEBUG_MODE) then
    showPopupIfAny('{"pop_up": {"message": "Would you like to click me?","links": [{"rel":"clicks","href": "http://api.bcfads.com/api/v4/conversions/4eaff81e0c5d880c29000001/clicks.json"}]}}')
  end
end

local function sendHTTPPost( path , content )
  if (content == nil) then
    return
  end
  url = urlForAPIPath(path)
  headers = {}
  headers["Content-Type"] = "application/json"
  params = {}
  params.body = content
  params.headers = headers
  log("REQUEST: " .. url .. " | " .. content)
  network.request(url, "POST", networkListener, params)
end

------ Device Identification

local function buildDeviceIdentifierAsTable()
  id = system.getInfo("deviceID")
  id = string.gsub(id, "-", "")
  id = string.lower(id)
  if (string.len(id)==40) then
    return {identities={udid=id}}
  elseif (string.len(id) == 15 or string.len(id) == 18) then
    return {identities={mobile_id=id}}
  else
    if (DEBUG_MODE) then
      return {identities={unknown=id}}
    end
    log("WARNING: device not identified, no registration or popup will work")
    return nil
  end
end

------ Request Building

local function buildRegisterPayloadAsJSONString()
  device = buildDeviceIdentifierAsTable()
  if (device == nil) then
    return nil
  end
  payloadTable = { device=device }
  return json.encode(payloadTable)
end

local function getManufacturer()
  manufacturer = system.getInfo("platformName")
  if (manufacturer == "iPhone OS") then
    return "Apple"
  end
  return manufacturer
end

local function getModel()
  manufacturer = getManufacturer()
  if (manufacturer == "Apple") then
    return system.getInfo("architectureInfo")
  end
  return system.getInfo("model")
end

local function buildShowPopupPayloadAsJSONString()
  basicPayload = buildRegisterPayloadAsJSONString()
  if (basicPayload == nil) then
    return nil
  end
  payloadTable = json.decode(basicPayload)
  payloadTable["country"] = system.getPreference( "locale", "country" )
  payloadTable["manufacturer"] = getManufacturer()
  payloadTable["model"] = getModel()
  payloadTable["os_version"] = system.getInfo("platformVersion")
  return json.encode(payloadTable)
end

------ Initialization

bcfads = { staging = false }
if (DEBUG_MODE) then
  log("WARNING: debug mode enabled. Responses will be ignored and dummy ads will be shown")
end

--============ Interface ============--

function bcfads.registerInstall( applicationIds )
    applicationId = applicationIds[system.getInfo("platformName")]
    path = "api/v4/mobile_apps/" .. applicationId .. "/install.json"
    content = buildRegisterPayloadAsJSONString()
    sendHTTPPost(path, content)
end

function bcfads.showPopup ( applicationIds )
    if system.getInfo("platformName") ~= "Android" and system.getInfo("platformName") ~= "iPhone OS" then
        log("WARNING: not Android or iPhone OS - "..system.getInfo("platformName"))
        return
    end
    applicationId = applicationIds[system.getInfo("platformName")]
    path = "api/v4/mobile_apps/" .. applicationId .. "/pop_ups/fetch.json";
    content = buildShowPopupPayloadAsJSONString()
    sendHTTPPost(path, content)
end

function bcfads.setStagingMode ( status )
  if (status==true or status==false) then
    bcfads.staging = status
  else
    error("Staging mode must be boolean (true to connect to staging, false to connect to production)")
  end
end
