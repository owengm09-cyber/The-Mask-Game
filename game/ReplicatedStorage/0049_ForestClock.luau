local C={CycleSeconds=24*60,StartHour=8}
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
return C
