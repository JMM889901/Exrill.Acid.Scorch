#if SERVER
untyped
#endif

global function MpTitanAbilityAcidPool_Init
global function OnWeaponPrimaryAttack_titanweapon_acid_pool
#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_acid_pool
#endif
const asset ACID_WALL_FX = $"P_wpn_meteor_wall_acid"
const asset ACID_WALL_FX_S2S = $"P_wpn_meteor_wall_s2s_acid"
const asset ACID_WALL_CHARGED_ADD_FX = $"impact_exp_burst_FRAG_2_acid"

const string ACID_WALL_PROJECTILE_SFX = "flamewall_flame_start"
const string ACID_WALL_GROUND_SFX = "Explo_ThermiteGrenade_Impact_3P"
const string ACID_WALL_GROUND_BEGINNING_SFX = "flamewall_flame_burn_front"
const string ACID_WALL_GROUND_MIDDLE_SFX = "flamewall_flame_burn_middle"
const string ACID_WALL_GROUND_END_SFX = "flamewall_flame_burn_end"
//TODO: Need to reassign ownership to whomever destroys the Barrel.
const asset DAMAGE_AREA_MODEL = $"models/fx/xo_shield.mdl"
const asset SLOW_TRAP_MODEL = $"models/weapons/titan_incendiary_trap/w_titan_incendiary_trap.mdl"
const asset SLOW_TRAP_FX_ALL = $"P_meteor_Trap_start_acid"
const float SLOW_TRAP_LIFETIME = 12.0
const float SLOW_TRAP_BUILD_TIME = 1.0
const float SLOW_TRAP_RADIUS = 240000
const asset TOXIC_FUMES_FX 	= $"P_meteor_trap_gas_acid"
const asset TOXIC_FUMES_S2S_FX 	= $"P_meteor_trap_gas_s2s_acid"
const asset FIRE_CENTER_FX = $"P_meteor_trap_center_acid"
const asset BARREL_EXP_FX = $"P_meteor_trap_EXP_acid"
const asset FIRE_LINES_FX = $"P_meteor_trap_burn"
const asset FIRE_LINES_S2S_FX = $"P_meteor_trap_burn_s2s_acid"
const float FIRE_TRAP_MINI_EXPLOSION_RADIUS = 75
const float FIRE_TRAP_LIFETIME = 10.5
const int GAS_FX_HEIGHT = 70

void function MpTitanAbilityAcidPool_Init()
{
	PrecacheModel( SLOW_TRAP_MODEL )
	PrecacheParticleSystem( SLOW_TRAP_FX_ALL )
	PrecacheParticleSystem( TOXIC_FUMES_FX )
	PrecacheParticleSystem( FIRE_CENTER_FX )
	PrecacheParticleSystem( FIRE_LINES_FX )
	PrecacheParticleSystem( BARREL_EXP_FX )

	if ( GetMapName() == "sp_s2s" )
	{
		PrecacheParticleSystem( TOXIC_FUMES_S2S_FX )
		PrecacheParticleSystem( FIRE_LINES_S2S_FX )
	}


	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.exrill_mp_titanability_acid_pool, AcidPool_DamagedPlayerOrNPC )
	#endif
}



#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_acid_pool( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_slow_trap( weapon, attackParams )
}
#endif

var function OnWeaponPrimaryAttack_titanweapon_acid_pool( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner() 
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	//ThrowDeployable( weapon, attackParams, 0.63, OnSlowTrapPlanted, <90,0,0> )
	entity player = weapon.GetWeaponOwner()
	vector attackPos
	if ( IsValid( player ) )
		attackPos = GetDeployableThrowStartPos( player, attackParams.pos )
	vector angles = VectorToAngles( attackParams.dir )
	attackPos.z = attackPos.z +25
	vector angularVelocity = <0,0,0>
	float fuseTime = 0.0
	float speed = weapon.GetWeaponSettingFloat(eWeaponVar.projectile_launch_speed)/2200
	vector forward = AnglesToForward( angles )
	if ( forward.x < 80 )
		speed = GraphCapped( forward.x, 0, 80, speed, speed * 3 )

	vector velocity = forward * speed
	if((weapon.GetWeaponChargeLevel() > 0))
		weaponOwner.TakeSharedEnergy( 250 )
		#if SERVER
	entity deployable = weapon.FireWeaponGrenade( attackPos, attackParams.dir, angularVelocity, fuseTime, damageTypes.explosive, damageTypes.explosive, false, true, true )
	//entity deployable = Grenade_Launch( weapon, attackParams.pos, (attackParams.dir * 1), projectilePredicted, projectileLagCompensated )
		if ( deployable )
		{
			print(weapon.GetWeaponChargeLevel())
			deployable.proj.isChargedShot = (weapon.GetWeaponChargeLevel() > 0)
			print(deployable.proj.isChargedShot)
			deployable.proj.savedAngles = Vector( 0, angles.y, 0 )
			Grenade_Init( deployable, weapon )
			thread OnProjectilePlanted( deployable, OnPoisonWallPlanted )
		}
	#endif
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}
#if SERVER
void function OnProjectilePlanted( entity projectile, void functionref(entity) deployFunc )
{
	projectile.EndSignal( "OnDestroy" )
	projectile.WaitSignal( "Planted" )
	deployFunc( projectile )
}
#endif
vector function GetDeployableThrowStartPos( entity player, vector baseStartPos )
{
	if ( player.IsTitan() )
	{
		int attachID = player.LookupAttachment( "TITAN_GRENADE" )
		vector attackPos = player.GetAttachmentOrigin( attachID )
		vector attackDir = player.GetAttachmentForward( attachID )
		return attackPos + ( attackDir * 50 )
	}

	vector attackPos = player.OffsetPositionFromView( baseStartPos, Vector( 15.0, 0.0, 0.0 ) )	// forward, right, up
	return attackPos
}

void function OnSlowTrapPlanted( entity projectile )
{
	#if SERVER
		thread OnPoisonWallPlanted( projectile )
	#endif
}
#if SERVER
void function OnPoisonWallPlanted( entity projectile )
{
	#if SERVER
		//thread DeployPoisonWall( projectile )
		
		vector origin = OriginToGround( projectile.GetOrigin() )
		projectile.SetOrigin(< origin.x, origin.y, origin.z+100 >)
		origin = <origin.x, origin.y, origin.z +100>
		float duration = ACID_WALL_THERMITE_DURATION
		if ( GAMETYPE == GAMEMODE_SP )
			duration *= SP_ACID_WALL_DURATION_SCALE
		entity inflictor = CreateOncePerTickDamageInflictorHelper( duration )
		inflictor.SetOrigin( origin )
		entity _parent = projectile.GetParent()
		if ( IsValid( _parent ) )
			projectile.SetParent( _parent, "", true, 0 )
		entity myParent = _parent
		// Increase the radius a bit so AI proactively try to get away before they have a chance at taking damage
		entity owner = projectile.GetOwner()
		entity movingGeo = ( myParent && myParent.HasPusherRootParent() ) ? myParent : null
		if ( movingGeo )
		{
			inflictor.SetParent( movingGeo, "", true, 0 )}
			for ( int i = 0; i < 12; i++ )
			{
				vector angles = < 0, 30 * i, 0 >

			vector direction =AnglesToForward( <angles.x,angles.y,angles.z> )
			print("direction "+direction)
			print("initial angles "+angles)
			const float FUSE_TIME = 0.0
			projectile.SetModel( $"models/dev/empty_model.mdl" )
			thread SpawnPoisonWave( projectile, 0, inflictor, origin, direction )
			}
			wait 5
			projectile.Destroy()
	#endif
		}
#if SERVER
void function SpawnPoisonWave( entity projectile, int projectileCount, entity inflictor, vector origin, vector direction )
{
	projectile.EndSignal( "OnDestroy" )
	projectile.SetAbsOrigin( projectile.GetOrigin() )
	projectile.SetAbsAngles( projectile.GetAngles() )
	projectile.SetVelocity( Vector( 0, 0, 0 ) )
	projectile.StopPhysics()
	projectile.SetTakeDamageType( DAMAGE_NO )
	projectile.Hide()
	projectile.NotSolid()
	projectile.proj.savedOrigin = < -999999.0, -999999.0, -999999.0 >
	waitthread WeaponAttackWave( projectile, projectileCount, inflictor, origin, direction, CreateAcidPoolSegment )
}

bool function CreateAcidPoolSegment( entity projectile, int projectileCount, entity inflictor, entity movingGeo, vector pos, vector angles, int waveCount )
{
	projectile.SetOrigin( pos )
	entity owner = projectile.GetOwner()

	if ( projectile.proj.savedOrigin != < -999999.0, -999999.0, -999999.0 > )
	{
		array<string> mods = projectile.ProjectileGetMods()
		float duration
		int damageSource
		if ( mods.contains( "pas_scorch_flamecore" ) )
		{
			damageSource = eDamageSourceId.mp_titancore_ACID_wave_secondary
			duration = 1.5
		}
		else
		{
			damageSource = eDamageSourceId.exrill_mp_titanability_acid_pool
			duration = mods.contains( "pas_scorch_firewall" ) ? PAS_VENOM_ACIDWALL_DURATION : ACID_WALL_THERMITE_DURATION
		}

		if ( IsSingleplayer() )
		{
			if ( owner.IsPlayer() || Flag( "SP_MeteorIncreasedDuration" ) )
			{
				duration *= SP_ACID_WALL_DURATION_SCALE
			}
		}

		entity thermiteParticle
		//regular script path
		if ( !movingGeo )
		{
			thermiteParticle = CreateThermiteTrail( pos, angles, owner, inflictor, duration, ACID_WALL_FX, damageSource )
			EffectSetControlPointVector( thermiteParticle, 1, projectile.proj.savedOrigin )
			AI_CreateDangerousArea_Static( thermiteParticle, projectile, METEOR_THERMITE_DAMAGE_RADIUS_DEF, TEAM_INVALID, true, true, pos )
		}
		else
		{
			if ( GetMapName() == "sp_s2s" )
			{
				angles = <0,90,0>//wind dir
				thermiteParticle = CreateThermiteTrailOnMovingGeo( movingGeo, pos, angles, owner, inflictor, duration, ACID_WALL_FX_S2S, damageSource )
			}
			else
			{
				thermiteParticle = CreateThermiteTrailOnMovingGeo( movingGeo, pos, angles, owner, inflictor, duration, ACID_WALL_FX, damageSource )
			}

			if ( movingGeo == projectile.proj.savedMovingGeo )
			{
				thread EffectUpdateControlPointVectorOnMovingGeo( thermiteParticle, 1, projectile.proj.savedRelativeDelta, projectile.proj.savedMovingGeo )
			}
			else
			{
				thread EffectUpdateControlPointVectorOnMovingGeo( thermiteParticle, 1, GetRelativeDelta( pos, movingGeo ), movingGeo )
			}
			AI_CreateDangerousArea( thermiteParticle, projectile, METEOR_THERMITE_DAMAGE_RADIUS_DEF, TEAM_INVALID, true, true )
		}

		//EmitSoundOnEntity( thermiteParticle, ACID_WALL_GROUND_SFX )
		int maxSegments = expect int( projectile.ProjectileGetWeaponInfoFileKeyField( "wave_max_count" ) )
		//figure out why it's starting at 1 but ending at 14.
		if ( waveCount == 1 )
			EmitSoundOnEntity( thermiteParticle, ACID_WALL_GROUND_BEGINNING_SFX )
		else if ( waveCount == ( maxSegments - 1 ) )
			EmitSoundOnEntity( thermiteParticle, ACID_WALL_GROUND_END_SFX )
		else if ( waveCount == maxSegments / 2  )
			EmitSoundOnEntity( thermiteParticle, ACID_WALL_GROUND_MIDDLE_SFX )
	}
	projectile.proj.savedOrigin = pos
	if ( IsValid( movingGeo ) )
	{
		projectile.proj.savedRelativeDelta = GetRelativeDelta( pos, movingGeo )
		projectile.proj.savedMovingGeo = movingGeo
	}

	return true
}

#endif


void function IncendiaryTrapFireSounds( entity inflictor )
{
	inflictor.EndSignal( "OnDestroy" )

	vector position = inflictor.GetOrigin()
	EmitSoundAtPosition( TEAM_UNASSIGNED, position, "incendiary_trap_burn" )
	OnThreadEnd(
	function() : ( position )
		{
			StopSoundAtPosition( position, "incendiary_trap_burn" )
			EmitSoundAtPosition( TEAM_UNASSIGNED, position, "incendiary_trap_burn_stop" )
		}
	)

	WaitForever()
}

void function FlameOn( entity inflictor )
{
	inflictor.EndSignal( "OnDestroy")
	float intialWaitTime = 0.3
	wait intialWaitTime

	float duration = FLAME_WALL_THERMITE_DURATION
	if ( GAMETYPE == GAMEMODE_SP )
		duration *= SP_FLAME_WALL_DURATION_SCALE
	foreach( key, pos in inflictor.e.fireTrapEndPositions )
	{
		entity fireLine = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( FIRE_LINES_FX ), pos, inflictor.GetAngles() )
		EntFireByHandle( fireLine, "Kill", "", duration, null, null )
		EffectSetControlPointVector( fireLine, 1, inflictor.GetOrigin() )
	}
}



void function EffectUpdateControlPointVectorOnMovingGeo( entity thermiteParticle, int cpIndex, vector relativeDelta, entity movingGeo )
{
	thermiteParticle.EndSignal( "OnDestroy" )

	while ( 1 )
	{
		vector origin = GetWorldOriginFromRelativeDelta( relativeDelta, movingGeo )

		EffectSetControlPointVector( thermiteParticle, cpIndex, origin )
		WaitFrame()
	}
}


void function SpawnFireLine( entity projectile, int projectileCount, entity inflictor, vector origin, vector direction )
{
	if ( !IsValid( projectile ) ) //unclear why this is necessary. We check for validity before creating the thread.
		return

	projectile.EndSignal( "OnDestroy" )
	entity owner = projectile.GetOwner()
	owner.EndSignal( "OnDestroy" )

	OnThreadEnd(
	function() : ( projectile )
		{
			if ( IsValid( projectile ) )
				projectile.Destroy()
		}
	)
	projectile.SetAbsOrigin( origin )
	projectile.SetAbsAngles( direction )
	projectile.proj.savedOrigin = < -999999.0, -999999.0, -999999.0 >

	wait RandomFloatRange( 0.0, 0.1 )
	
	waitthread WeaponAttackWave( projectile, projectileCount, inflictor, origin, direction, CreateSlowTrapSegment )
}

void function CreateToxicFumesFXSpot( vector origin, entity tower )
{
	int fxID = GetParticleSystemIndex( TOXIC_FUMES_FX )
	int attachID = tower.LookupAttachment( "smoke" )
	entity particleSystem = StartParticleEffectOnEntityWithPos_ReturnEntity( tower, fxID, FX_PATTACH_POINT_FOLLOW, attachID, <0,0,0>, <0,0,0> )

	tower.e.fxArray.append( particleSystem )
}

void function CreateToxicFumesInWindFX( vector origin, entity tower )
{
	int fxID = GetParticleSystemIndex( TOXIC_FUMES_S2S_FX )
	int attachID = tower.LookupAttachment( "smoke" )

	entity particleSystem = StartParticleEffectOnEntityWithPos_ReturnEntity( tower, fxID, FX_PATTACH_POINT_FOLLOW_NOROTATE, attachID, <0,0,0>, <0,90,0> )

	tower.e.fxArray.append( particleSystem )
}

bool function CreateSlowTrapSegment( entity projectile, int projectileCount, entity inflictor, entity movingGeo, vector pos, vector angles, int waveCount )
{
	projectile.SetOrigin( pos )
	entity owner = projectile.GetOwner()
	if ( projectile.proj.savedOrigin != < -999999.0, -999999.0, -999999.0 > )
	{
		float duration = FLAME_WALL_THERMITE_DURATION
		if ( GAMETYPE == GAMEMODE_SP )
			duration *= SP_FLAME_WALL_DURATION_SCALE

		if ( !movingGeo )
		{
			if ( projectileCount in inflictor.e.fireTrapEndPositions )
				inflictor.e.fireTrapEndPositions[projectileCount] = pos
			else
				inflictor.e.fireTrapEndPositions[projectileCount] <- pos

			thread FireTrap_DamageAreaOverTime( owner, inflictor, pos, duration )
		}
		else
		{
			vector relativeDelta = GetRelativeDelta( pos, movingGeo )

			if ( projectileCount in inflictor.e.fireTrapEndPositions )
				inflictor.e.fireTrapEndPositions[projectileCount] = relativeDelta
			else
				inflictor.e.fireTrapEndPositions[projectileCount] <- relativeDelta

			if ( projectileCount in inflictor.e.fireTrapMovingGeo )
				inflictor.e.fireTrapMovingGeo[projectileCount] = movingGeo
			else
				inflictor.e.fireTrapMovingGeo[projectileCount] <- movingGeo

			thread FireTrap_DamageAreaOverTimeOnMovingGeo( owner, inflictor, movingGeo, relativeDelta, duration )
		}

	}

	projectile.proj.savedOrigin = pos
	return true
}

void function FireTrap_DamageAreaOverTime( entity owner, entity inflictor, vector pos, float duration )
{
	Assert( IsValid( owner ) )
	owner.EndSignal( "OnDestroy" )
	float endTime = Time() + duration
	while ( Time() < endTime )
	{
		FireTrap_RadiusDamage( pos, owner, inflictor )
		wait 0.2
	}
}

void function FireTrap_DamageAreaOverTimeOnMovingGeo( entity owner, entity inflictor, entity movingGeo, vector relativeDelta, float duration )
{
	Assert( IsValid( owner ) )
	owner.EndSignal( "OnDestroy" )
	movingGeo.EndSignal( "OnDestroy" )
	inflictor.EndSignal( "OnDestroy" )

	float endTime = Time() + duration
	while ( Time() < endTime )
	{
		vector pos = GetWorldOriginFromRelativeDelta( relativeDelta, movingGeo )
		FireTrap_RadiusDamage( pos, owner, inflictor )
		wait 0.2
	}
}

void function FireTrap_RadiusDamage( vector pos, entity owner, entity inflictor )
{
	MeteorRadiusDamage meteorRadiusDamage = GetMeteorRadiusDamage( owner )
	float METEOR_DAMAGE_TICK_PILOT = meteorRadiusDamage.pilotDamage
	float METEOR_DAMAGE_TICK = meteorRadiusDamage.heavyArmorDamage

	RadiusDamage(
		pos,												// origin
		owner,												// owner
		inflictor,		 									// inflictor
		METEOR_DAMAGE_TICK_PILOT,							// pilot damage
		METEOR_DAMAGE_TICK,									// heavy armor damage
		FIRE_TRAP_MINI_EXPLOSION_RADIUS,					// inner radius
		FIRE_TRAP_MINI_EXPLOSION_RADIUS,					// outer radius
		SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,					// explosion flags
		0, 													// distanceFromAttacker
		0, 													// explosionForce
		DF_EXPLOSION,										// damage flags
		eDamageSourceId.exrill_mp_titanability_acid_pool			// damage source id
	)
}

void function AcidPool_DamagedPlayerOrNPC( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if ( !IsValid( inflictor ) )
		return
	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_DOOMED_HEALTH_LOSS )
		return
	Thermite_DamagePlayerOrNPCSounds( ent )

	float originDistance2D = Distance2D( inflictor.GetOrigin(), DamageInfo_GetDamagePosition( damageInfo ) )
	if ( originDistance2D > SLOW_TRAP_RADIUS )
		DamageInfo_SetDamage( damageInfo, 0 )
	else
		Scorch_SelfDamageReduction( ent, damageInfo )

	DamageInfo_ScaleDamage( damageInfo, 0.3 )
	StatusEffect_AddTimed( ent, eStatusEffect.move_slow, 0.7, 1, 1 )
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || attacker.GetTeam() == ent.GetTeam() ){
		return}

	array<entity> weapons = attacker.GetMainWeapons()
	if ( weapons.len() > 0 )
	{
		if ( weapons[0].HasMod( "fd_fire_damage_upgrade" )  )
			DamageInfo_ScaleDamage( damageInfo, FD_FIRE_DAMAGE_SCALE )
		if ( weapons[0].HasMod( "fd_hot_streak" ) )
			UpdateScorchHotStreakCoreMeter( attacker, DamageInfo_GetDamage( damageInfo ) )
	}
	
}
#endif

//	TODO:
//	Reassign damage to person who triggers the trap for FF reasons.
