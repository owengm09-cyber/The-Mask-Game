local Fortune=require(game.ReplicatedStorage:WaitForChild("FortuneConfig"))
local Passes=require(game.ReplicatedStorage:WaitForChild("GamePassConfig"))
local R={}
function R.Odds(kind,hasLuck)
    local cards=assert(Fortune.Cards[kind],"Unknown fortune deck")
    local common,rare={},{}
    local isPerk=kind=="SurvivorPerks" or kind=="KillerPerks"
    for _,card in cards do
        table.insert(isPerk and card.Rarity=="Rare" and rare or common,card)
    end
    local chance=math.clamp(Passes.RarePerkChance*(hasLuck and Passes.LuckMultiplier or 1),0,1)
    if #rare==0 then chance=0 elseif #common==0 then chance=1 end
    local result={}
    for _,card in common do table.insert(result,{Card=card,Chance=(1-chance)/#common}) end
    for _,card in rare do table.insert(result,{Card=card,Chance=chance/#rare}) end
    return result
end
function R.Roll(kind,hasLuck,rng)
    local odds=R.Odds(kind,hasLuck)
    local roll=(rng or Random.new()):NextNumber()
    local cumulative=0
    for _,entry in odds do
        cumulative+=entry.Chance
        if roll<cumulative then return entry.Card end
    end
    return odds[#odds].Card
end
return R
