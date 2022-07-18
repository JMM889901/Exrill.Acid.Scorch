global function MpTitanWeaponVirus_shot
global function OnWeaponAttemptOffhandSwitch_titanweapon_virus_shot
global function OnWeaponPrimaryAttack_titanweapon_virus_shot

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_virus_shot
#endif
struct InactiveViralStackStruct
{
    entity target
    entity owner
    float duration
    int ID
}
struct ActiveViralStacksStruct
{
    entity target
    entity owner
    float duration
    int StackCount
    int ID
}
struct PlayerStacksStruct
{
    entity owner //Just for sanity check really
    array<InactiveViralStackStruct> InactiveStacks
    array<ActiveViralStacksStruct> ActiveStacks
}

const TICKTIME = 0.1
table<entity, PlayerStacksStruct> PlayerStackStuff
struct {
	float chargeDownSoundDuration = 1.0 //"charge_cooldown_time"
} file
void function MpTitanWeaponVirus_shot()
{
	RegisterSignal("VirusSpreadStart")
	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.exrill_mp_titanability_viral_shot, ViralShot_DamagedTarget )
	#endif
	PrecacheParticleSystem($"P_meteor_trap_burn_acid")
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_virus_shot( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	int curCost = weapon.GetWeaponCurrentEnergyCost()
	bool canUse = owner.CanUseSharedEnergy( curCost )

	#if CLIENT
		if ( !canUse )
			FlashEnergyNeeded_Bar( curCost )
	#endif
	return canUse
}

var function OnWeaponPrimaryAttack_titanweapon_virus_shot( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if CLIENT
		if ( !weapon.ShouldPredictProjectiles() )
			return 1
	#endif

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.SetWeaponChargeFractionForced(1.0)
	return 1
}
#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_virus_shot( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_laser_lite( weapon, attackParams )
}

void function ViralShot_DamagedTarget( entity target, var damageInfo )
{
	if ( target.IsTitan() )
		CuttingBeamAddOrUpdateStacks(target, damageInfo)
}

void function CuttingBeamAddOrUpdateStacks(entity victim, var damageInfo)
{
	entity Owner = DamageInfo_GetAttacker(damageInfo)
    if(!(victim in PlayerStackStuff))
    {
        PlayerStacksStruct NewStackStruct
        PlayerStackStuff[victim] <- NewStackStruct
    }
	if(PlayerStackStuff[victim].ActiveStacks.len() < 1)
	{
		ActiveViralStacksStruct HitStruct
		HitStruct.target = victim
		HitStruct.owner = Owner
		HitStruct.StackCount = 1
		HitStruct.duration = 5
		PlayerStackStuff[victim].ActiveStacks.append(HitStruct)
		thread AcidStackThink(HitStruct)
	} 
	else
	{
		PlayerStackStuff[victim].ActiveStacks[0].duration = 5
		PlayerStackStuff[victim].ActiveStacks[0].StackCount++
	}
}

void function AcidStackThink(ActiveViralStacksStruct ActiveStruct)
{
    entity owner = ActiveStruct.owner
    entity target = ActiveStruct.target

    #if SERVER  
    int fxID = GetParticleSystemIndex( $"P_meteor_trap_burn_acid" )
	int attachID = target.LookupAttachment( "exp_torso_front" )
    entity particleSystem = StartParticleEffectOnEntityWithPos_ReturnEntity( target, fxID, FX_PATTACH_POINT_FOLLOW, attachID, <0,0,0>, <0,0,0> )
    int StackCount = ActiveStruct.StackCount
    while(ActiveStruct.duration > 0)
    {
		target.TakeDamage( 10*ActiveStruct.StackCount, owner, owner, eDamageSourceId.exrill_mp_titanability_viral_shot_secondary)	
        //print(ActiveStruct.StackCount)
		wait TICKTIME
        ActiveStruct.duration = ActiveStruct.duration - TICKTIME
    }
    if ( IsValid( particleSystem ) )
    {
		particleSystem.Destroy()
    }
    PlayerStackStuff[target].ActiveStacks.fastremovebyvalue(ActiveStruct)
    #endif
}
#endif
