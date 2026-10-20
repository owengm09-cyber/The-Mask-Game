-- StartHour is where the clock begins each round. Night starts at 19:00 and one game hour lasts 60 s, so 14 puts the
-- first night (and the first mask) 5 minutes in; the original 8 put it 11 minutes in. Override per server with the
-- MaskSystem attribute "StartHour" (any hour from 0 up to, but not including, 24).
local C={CycleSeconds=24*60,StartHour=14}
function C.ResolveStartHour(value)
 if type(value)=="number" and value==value and value>=0 and value<24 then return value end
 return C.StartHour
end
function C.Advance(hour,dt,paused) return (hour+(paused and 0 or dt*24/C.CycleSeconds))%24 end
function C.Phase(hour) return hour>=6 and hour<19 and "Day" or "Night" end
function C.Remaining(hour) return (C.Phase(hour)=="Day" and 19-hour or (6-hour)%24)*C.CycleSeconds/24 end
function C.SolarHour(hour)
 if hour>=6 and hour<19 then return 6+(hour-6)*12/13 end
 return (18+((hour-19)%24)*12/11)%24
end
function C.Format(hour)
 local minutes=math.floor((hour%24)*60+0.000001)
 local h=math.floor(minutes/60)
 return string.format("%d:%02d %s",h%12==0 and 12 or h%12,minutes%60,h<12 and "AM" or "PM")
end
-- HUD text for a player who is not playing right now (DreadHUD). The label fits about 24 characters.
-- state: "Eliminated", "Escaped" or nil (between trials, or joined while one is running).
function C.SideRole(state) return state=="Eliminated" and "ELIMINATED" or state=="Escaped" and "ESCAPED" or "LOBBY" end
function C.SideLine(state,matchActive,roundState,alive,done,total,van)
 if state=="Escaped" then return "WAIT FOR THE BUS" end
 if state=="Eliminated" then
  local plan=van=="Running" and "BUS IS HERE" or van=="Gone" and "BUS HAS GONE" or ("PLAN "..done.."/"..total)
  return alive.." LEFT • "..plan
 end
 if matchActive then return "JOINING NEXT TRIAL" end
 if roundState=="Picking" then return "TRIAL STARTING" end
 return "WAITING FOR PLAYERS"
end
return C
