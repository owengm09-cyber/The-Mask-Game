local C = {
    VIPXPBonus = 0.30,
    RarePerkChance = 0.20,
    LuckMultiplier = 2,
    Passes = {
        {Key="VIP", Id=2006475706, Title="VIP", Mark="VIP",
         Description="+30% XP at the end of every round.\nExclusive gold VIP name tag."},
        {Key="PerkLuck", Id=2008089704, Title="2× PERK LUCK", Mark="2×",
         Description="Rare perk chance: 20% → 40%.\nCommon perk chance: 80% → 60%.",
         RequiresRandomItems=true},
    },
}
function C.Get(key)
    for _,pass in C.Passes do if pass.Key==key then return pass end end
end
return C
