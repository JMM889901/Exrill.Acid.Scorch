global function OnWeaponActivate_titancore_acid_wave
global function MpTitanWeaponAcidWave_Init

global function OnAbilityCharge_AcidWave
global function OnAbilityChargeEnd_AcidWave

global function OnWeaponPrimaryAttack_titancore_acid_wave

const float PROJECTILE_SEPARATION = 128
const float ACID_WALL_MAX_HEIGHT = 110
const asset ACID_WAVE_IMPACT_TITAN = $"P_impact_exp_med_metal_acid"
const asset ACID_WAVE_IMPACT 		= $"P_impact_exp_xsmll_metal_acid"
const asset ACIDWAVE_EFFECT 		= $"P_wpn_meteor_wave_acid"
const asset ACIDWAVE_EFFECT_CONTROL = $"P_wpn_meteor_waveCP_acid"

const string ACID_WAVE_LEFT_SFX = "flamewave_blast_left"
const string ACID_WAVE_MIDDLE_SFX = "flamewave_blast_middle"
const string ACID_WAVE_RIGHT_SFX = "flamewave_blast_right"

const asset ACID_WALL_FX = $"P_wpn_meteor_wall_acid"
const asset ACID_WALL_FX_S2S = $"P_wpn_meteor_wall_s2s_acid"
const asset ACID_WALL_CHARGED_ADD_FX = $"impact_exp_burst_FRAG_2_acid"

const string ACID_WALL_PROJECTILE_SFX = "flamewall_flame_start"
const string ACID_WALL_GROUND_SFX = "Explo_ThermiteGrenade_Impact_3P"
const string ACID_WALL_GROUND_BEGINNING_SFX = "flamewall_flame_burn_front"
const string ACID_WALL_GROUND_MIDDLE_SFX = "flamewall_flame_burn_middle"
const string ACID_WALL_GROUND_END_SFX = "flamewall_flame_burn_end"

void function MpTitanWeaponAcidWave_Init()
{
	PrecacheParticleSystem( ACID_WAVE_IMPACT_TITAN )
	PrecacheParticleSystem( ACID_WAVE_IMPACT )
	PrecacheParticleSystem( ACIDWAVE_EFFECT )
	PrecacheParticleSystem( ACIDWAVE_EFFECT_CONTROL )

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.exrill_mp_titancore_acid_river, AcidWave_DamagedPlayerOrNPC )
	#endif
}

void function OnWeaponActivate_titancore_acid_wave( entity weapon )
{
	weapon.EmitWeaponSound_1p3p( "flamewave_start_1p", "flamewave_start_3p" )
	OnAbilityCharge_TitanCore( weapon )
}


bool function OnAbilityCharge_AcidWave( entity weapon )
{
	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		float chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
		entity soul = owner.GetTitanSoul()
		if ( soul == null )
			soul = owner
		StatusEffect_AddTimed( soul, eStatusEffect.move_slow, 0.6, chargeTime, 0 )
		StatusEffect_AddTimed( soul, eStatusEffect.dodge_speed_slow, 0.6, chargeTime, 0 )
		StatusEffect_AddTimed( soul, eStatusEffect.damageAmpFXOnly, 1.0, chargeTime, 0 )

		if ( owner.IsPlayer() )
			owner.SetTitanDisembarkEnabled( false )
		else
			owner.Anim_ScriptedPlay( "at_antirodeo_anim_fast" )
	#endif

	return true
}

void function OnAbilityChargeEnd_AcidWave( entity weapon )
{
	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		if ( owner.IsPlayer() )
			owner.SetTitanDisembarkEnabled( true )
		OnAbilityChargeEnd_TitanCore( weapon )
	#endif // #if SERVER
}

var function OnWeaponPrimaryAttack_titancore_acid_wave( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnAbilityStart_TitanCore( weapon )

	#if SERVER
	OnAbilityEnd_TitanCore( weapon )
	#endif
	bool shouldPredict = weapon.ShouldPredictProjectiles()
	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif

	#if SERVER
	//This wave attack is spawning 3 waves, and we want them all to only do damage once to any individual target.
	entity inflictor = CreateDamageInflictorHelper( 10.0 )
	entity scorchedEarthInflictor = CreateOncePerTickDamageInflictorHelper( 10.0 )
	#endif

	array<float> offsets = [0.0]
	array<string> soundFXs = [ACID_WAVE_MIDDLE_SFX]
	Assert( offsets.len() == soundFXs.len(), "There should be a sound for each projectile." )
	int count = 0
		//JFS - Bug 210617
		Assert( IsValid( weapon.GetWeaponOwner() ), "JFS returning out - need to investigate why the owner is invalid." )
		if ( !IsValid( weapon.GetWeaponOwner() ) )
			return

		vector right = CrossProduct( attackParams.dir, <0,0,1> )
		vector offset = offsets[count] * right * PROJECTILE_SEPARATION

		const float FUSE_TIME = 99.0
		entity projectile = weapon.FireWeaponGrenade( attackParams.pos + offset, attackParams.dir, < 0,0,0 >, FUSE_TIME, damageTypes.projectileImpact, damageTypes.explosive, shouldPredict, true, true )
		if ( IsValid( projectile ) )
		{
			#if SERVER
				EmitSoundOnEntity( projectile, soundFXs[count] )
				weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.5 )
				thread OnPoisonWallPlanted( projectile)
				if ( weapon.HasMod( "pas_scorch_flamecore" ) )
					thread BeginScorchedEarth( projectile, count, scorchedEarthInflictor, attackParams.pos + offset, attackParams.dir )
			#elseif CLIENT
				ClientScreenShake( 8.0, 10.0, 1.0, Vector( 0.0, 0.0, 0.0 ) )
			#endif
	}

	return 1
}


void function OnPoisonWallPlanted( entity projectile )
{
	#if SERVER
		//thread DeployPoisonWall( projectile )
		
		vector origin = OriginToGround( projectile.GetOrigin() )
		projectile.SetOrigin(< origin.x, origin.y, origin.z+250 >)
		origin = <origin.x, origin.y, origin.z +250>
		float duration = 6
		if ( GAMETYPE == GAMEMODE_SP )
			duration *= 1.5
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
			for ( int i = 0; i < 24; i++ )
			{
				vector angles = < 0, 360/24 * i, 0 >
			vector direction =AnglesToForward( <angles.x,angles.y,angles.z> )
			print("origin "+origin)
			print("direction "+direction)
			print("initial angles "+angles)
			const float FUSE_TIME = 0.0
			projectile.SetModel( $"models/dev/empty_model.mdl" )
			thread BeginAcidWave( projectile, 0, inflictor, origin+direction*150, direction )
			}
			wait 5
			if(IsValid(projectile))
				projectile.Destroy()
	#endif
		}


#if SERVER
void function BeginAcidWave( entity projectile, int projectileCount, entity inflictor, vector pos, vector dir )
{
	projectile.EndSignal( "OnDestroy" )
	projectile.SetAbsOrigin( projectile.GetOrigin() )
	projectile.SetAbsAngles( projectile.GetAngles() )
	projectile.SetVelocity( Vector( 0, 0, 0 ) )
	projectile.StopPhysics()
	projectile.SetTakeDamageType( DAMAGE_NO )
	projectile.Hide()
	projectile.NotSolid()
	waitthread WeaponAttackWave( projectile, projectileCount, inflictor, pos, dir, CreateAcidWaveSegment )
}

void function BeginScorchedEarth( entity projectile, int projectileCount, entity inflictor, vector pos, vector dir )
{
	if ( !IsValid( projectile ) )
		return
	projectile.EndSignal( "OnDestroy" )
	waitthread WeaponAttackWave( projectile, projectileCount, inflictor, pos, dir, CreateThermiteWallSegment )
	projectile.Destroy()
}

bool function CreateAcidWaveSegment( entity projectile, int projectileCount, entity inflictor, entity movingGeo, vector pos, vector angles, int waveCount )
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
			damageSource = eDamageSourceId.exrill_mp_titancore_acid_river
			duration = 10
		}
		else
		{
			damageSource = eDamageSourceId.exrill_mp_titancore_acid_river
			duration = mods.contains( "pas_scorch_firewall" ) ? 6.0 : 7.5
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

void function AcidWave_DamagedPlayerOrNPC( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_DOOMED_HEALTH_LOSS )
		return

	vector damagePosition = DamageInfo_GetDamagePosition( damageInfo )
	vector entOrigin = ent.GetOrigin()
	vector entCenter = ent.GetWorldSpaceCenter()
	float originDistanceZ = entOrigin.z - damagePosition.z
	float centerDistanceZ = entCenter.z - damagePosition.z
	float originDistance2D = Distance2D( entOrigin, damagePosition )

	if ( originDistanceZ > ACID_WALL_MAX_HEIGHT && centerDistanceZ > ACID_WALL_MAX_HEIGHT )
		ZeroDamageAndClearInflictorArray( ent, damageInfo )
	//else if ( originDistance2D > PROJECTILE_SEPARATION / 2 )
	//	ZeroDamageAndClearInflictorArray( ent, damageInfo )

	//Needs a unique impact sound.
	if ( ent.IsPlayer() )
	{
	 	EmitSoundOnEntityOnlyToPlayer( ent, ent, "Flesh.ThermiteBurn_3P_vs_1P" )
		EmitSoundOnEntityExceptToPlayer( ent, ent, "Flesh.ThermiteBurn_1P_vs_3P" )
	}
	else
	{
	 	EmitSoundOnEntity( ent, "Flesh.ThermiteBurn_1P_vs_3P" )
	}

	if ( DamageInfo_GetDamage( damageInfo ) > 0 )
	{

		Scorch_SelfDamageReduction( ent, damageInfo )
	}
	DamageInfo_ScaleDamage( damageInfo, 0.5 )
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) || attacker.GetTeam() == ent.GetTeam() ){
		DamageInfo_ScaleDamage( damageInfo, 0.0 )
		return}
	StatusEffect_AddTimed( ent, eStatusEffect.move_slow, 1, 1, 1 )
	array<entity> weapons = attacker.GetMainWeapons()
	if ( weapons.len() > 0 )
	{
		if ( weapons[0].HasMod( "fd_fire_damage_upgrade" )  )
			DamageInfo_ScaleDamage( damageInfo, FD_FIRE_DAMAGE_SCALE )
		if ( weapons[0].HasMod( "fd_hot_streak" ) )
			UpdateScorchHotStreakCoreMeter( attacker, DamageInfo_GetDamage( damageInfo ) )
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
void function ZeroDamageAndClearInflictorArray( entity ent, var damageInfo )
{
		DamageInfo_SetDamage( damageInfo, 0 )

		//This only works because Acid Wave doesn't leave lingering effects.
		entity inflictor = DamageInfo_GetInflictor( damageInfo )
		if ( inflictor.e.damagedEntities.contains( ent ) )
			inflictor.e.damagedEntities.fastremovebyvalue( ent )
}
#endif