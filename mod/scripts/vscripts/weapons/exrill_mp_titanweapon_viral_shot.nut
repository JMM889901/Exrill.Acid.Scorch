global function MpTitanWeaponVirus_shot
global function OnWeaponAttemptOffhandSwitch_titanweapon_virus_shot
global function OnWeaponPrimaryAttack_titanweapon_virus_shot

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_virus_shot
#endif

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
	entity weapon = DamageInfo_GetWeapon( damageInfo )
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if(!IsPlayer(target) || !target.IsTitan())
		return
	if ( attacker == target )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}
	print("what")
	DamageInfo_SetDamage( damageInfo, 2 )
	thread StartVirus(attacker, target, 10.0)
	if(target.IsTitan())
	{
	thread StartVirusSpread(attacker, target, 10.0)
	thread CreateSmoke(attacker, target, 10.0)
	}
}

void function StartVirus(entity attacker, entity target, float duration)
{
	if(!IsValid(target))
		return
	target.EndSignal("OnDestroy")
	target.EndSignal("OnDeath")
	float timeleft = duration 
	while(timeleft > 0){
		wait 0.5
		timeleft = timeleft - 0.5
		if(IsValid(target))
			target.TakeDamage( 7, attacker, attacker, eDamageSourceId.exrill_mp_titanability_viral_shot_secondary)	
	}
}
array<entity> infected
void function StartVirusSpread(entity attacker, entity target, float duration)
{
	if(!IsValid(target))
		return
	print(target)
	target.EndSignal("OnDestroy")
	target.EndSignal("OnDeath")
	float timeleft = duration 
	infected.append(target)
	OnThreadEnd(
		function() : ( target )
		{
			infected.fastremovebyvalue(target)
		}
	)
	while(timeleft > 0)
	{
		wait 0.5
		timeleft = timeleft - 0.5
		if(IsValid(target) && IsValid(attacker))
		{
			foreach(entity player in GetTitanArrayOfEnemies( attacker.GetTeam() ))
			{
				print(player)
				if(Distance( target.GetOrigin(), player.GetOrigin() ) < 350)
				{
					thread StartVirus(attacker, player, timeleft)
					if(!infected.contains(player))
					{
						thread StartVirusSpread(attacker ,player, timeleft)
					if(attacker != player)
						thread CreateSmoke(attacker, player, timeleft)
					}
				}
			}
		}
	}
}
table<entity, array<entity> > ToxinFXArrays = {}
const asset TOXIC_FUMES_FX 	= $"P_meteor_trap_gas_acid"
entity function CreateSmoke(entity attacker, entity titan, float timeleft)
{
	if(!titan.IsTitan())
		return
	int fxID = GetParticleSystemIndex( $"P_meteor_trap_burn_acid" )
	int attachID = titan.LookupAttachment( "exp_torso_front" )
	entity particleSystem = StartParticleEffectOnEntityWithPos_ReturnEntity( titan, fxID, FX_PATTACH_POINT_FOLLOW, attachID, <0,0,0>, <0,0,0> )
	wait timeleft
	if ( IsValid( particleSystem ) )
	{
		particleSystem.Destroy()
	}
}
#endif
