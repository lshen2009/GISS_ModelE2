#include "rundeck_opts.h"
      module trdust_drv
!@sum  trdust_drv routines with resolution dependent variables for
!@+               soil dust aerosols
!@auth Jan Perlwitz
#if (defined TRACERS_DUST) || (defined TRACERS_MINERALS) ||\
    (defined TRACERS_AMP) || (defined TRACERS_TOMAS)

      use filemanager,only: nameunit,openunit,closeunit
      use constant, only: rgas
      use resolution, only: im,jm,lm
      use param, only : sync_param
      use domain_decomp_atm, only: am_i_root,grid,dread_parallel
     &     ,esmf_bcast,write_parallel,get
      use model_com, only: coupled_chem,ioread,iowrite,irsfic,irsficno
     &     ,irerun,JDperY,JMperY,itime,t
      use dynamics, only: byam,pk,pmid
      use fluxes, only: dust_flux_glob,dust_flux2_glob
#ifdef TRACERS_DRYDEP
     &     ,depo_turb_glob,depo_grav_glob
#endif
#ifdef TRACERS_WATER
     &     ,trprec
#else
     &     ,trprec_dust
#endif
      use tracer_com, only: n_clay, n_clayilli, n_claykaol, n_claysmec,
     $     n_claycalc, n_clayquar, n_clayfeld, n_clayhema, n_claygyps,
     $     n_clayilhe, n_claykahe, n_claysmhe, n_claycahe, n_clayquhe,
     $     n_clayfehe, n_claygyhe, n_sil1quar, n_sil1feld, n_sil1calc,
     $     n_sil1illi, n_sil1kaol, n_sil1smec, n_sil1hema, n_sil1gyps,
     $     n_sil1quhe, n_sil1fehe, n_sil1cahe, n_sil1gyhe, n_sil1ilhe,
     $     n_sil1kahe, n_sil1smhe, n_sil2quar, n_sil2feld, n_sil2calc,
     $     n_sil2hema, n_sil2gyps, n_sil2illi, n_sil2kaol, n_sil2smec,
     $     n_sil2quhe, n_sil2fehe, n_sil2cahe, n_sil2gyhe, n_sil2ilhe,
     $     n_sil2kahe, n_sil2smhe, n_sil3quar, n_sil3feld, n_sil3calc,
     $     n_sil3hema, n_sil3gyps, n_sil3illi, n_sil3kaol, n_sil3smec,
     $     n_sil3quhe, n_sil3fehe, n_sil3cahe, n_sil3gyhe, n_sil3ilhe,
     $     n_sil3kahe, n_sil3smhe, n_sil4quar, n_sil4feld, n_sil4calc,
     $     n_sil4hema, n_sil4gyps, n_sil4illi, n_sil4kaol, n_sil4smec,
     $     n_sil4quhe, n_sil4fehe, n_sil4cahe, n_sil4gyhe, n_sil4ilhe,
     $     n_sil4kahe, n_sil4smhe, n_sil5quar, n_sil5feld, n_sil5calc,
     $     n_sil5hema, n_sil5gyps, n_sil5illi, n_sil5kaol, n_sil5smec,
     $     n_sil5quhe, n_sil5fehe, n_sil5cahe, n_sil5gyhe, n_sil5ilhe,
     $     n_sil5kahe, n_sil5smhe, n_soilDust, ntm_dust, ntm_clay,
     $     trm, trname, trpdens
#ifdef TRACERS_MINERALS
     &     ,ntm_sil1, ntm_sil2, ntm_sil3, ntm_sil4
#endif
#ifdef TRACERS_DRYDEP
     &     ,dodrydep
#endif
#ifdef TRACERS_WATER
     &     ,dowetdep
#endif
      use trdiag_com, only: trcsurf,trcSurfByVol,to_conc
      use tracers_dust
#ifdef NEW_IO
      use pario, only: defvar,read_dist_data,write_dist_data
#endif
      use netcdf

      implicit none

      integer :: i_0, i_1, j_0, j_1, i_0h, i_1h, j_0h, j_1h

#endif /* TRACERS_DUST || TRACERS_MINERALS || TRACERS_AMP || TRACERS_TOMAS */

      contains

c init_soildust
      subroutine init_soildust
!@sum init_soildust initializiations for soil dust/mineral dust aerosols
!@+   at startup
!@auth Jan Perlwitz
#if (defined TRACERS_DUST) || (defined TRACERS_MINERALS) ||\
    (defined TRACERS_AMP) || (defined TRACERS_TOMAS)

      implicit none

      logical, save :: qfirst = .true.

      integer :: n, n1

      if ( .not. qfirst ) return
      qfirst = .false.

#ifdef TRACERS_DUST
      n_soilDust = n_clay
#else
#ifdef TRACERS_MINERALS
      n_soilDust = n_clayilli
#endif
#endif

#ifndef TRACERS_AMP
#ifndef TRACERS_TOMAS
c**** initialize dust names
      do n=1,Ntm_dust
        n1=n_soilDust+n-1
        dust_names(n) = trname(n1)
      end do
c**** insert to_conc_soildust into to_conc

      if ( .not. any( to_conc( n_soilDust:n_soilDust+ntm_dust-1 ) > 0 )
     &     ) then
        call sync_param( 'to_conc_soildust', to_conc_soildust )
        to_conc( n_soilDust:n_soilDust+ntm_dust-1 ) = to_conc_soildust
      end if
#endif
#endif

#ifdef TRACERS_MINERALS
      call sync_param( 'brittleFactor', brittleFactor, nMinerals )
      call sync_param( 'calcMineralAggrProb', calcMineralAggrProb )
      call sync_param( 'soilDustEmissionDistr', soilDustEmissionDistr )
      call sync_param( 'calcEffectiveRadius', calcEffectiveRadius )
#endif

#endif /* TRACERS_DUST || TRACERS_MINERALS || TRACERS_AMP */
      return
      end subroutine init_soildust

c tracer_ic_soildust
      subroutine tracer_ic_soildust
!@sum  tracer_ic_soildust reads in source and parameter files for
!@+    dust/mineral tracer at itime_tr0
!@auth Jan Perlwitz
#if (defined TRACERS_DUST) || (defined TRACERS_MINERALS) ||\
    (defined TRACERS_AMP) || (defined TRACERS_TOMAS) 

      IMPLICIT NONE

      integer :: i, ierr, j, io_data, k, m
      INTEGER startd(3),countd(3),statusd
      INTEGER idd1,idd2,idd3,idd4,ncidd1,ncidd2,ncidd3,ncidd4
      REAL*8 :: zsum,tabsum
c**** temporary array to read in data
      REAL*4,DIMENSION(grid%i_strt:grid%i_stop,
     &                 grid%j_strt:grid%j_stop) :: work ! no halo

      LOGICAL,SAVE :: qfirst=.TRUE.
      CHARACTER :: cierr*3,name*256
      CHARACTER(80) :: OptModelVers='No Entry'

      IF (.NOT. qfirst) RETURN
      qfirst=.FALSE.

      call get(grid, j_strt=j_0, j_stop=j_1, i_strt=i_0, i_stop=i_1,
     &     j_strt_halo=j_0h, j_stop_halo=j_1h, i_strt_halo=i_0h,
     &     i_stop_halo=i_1h )

c**** read in lookup table for calculation of mean surface wind speed from PDF
      IF (am_i_root()) THEN
        CALL openunit('LKTAB1',io_data,.TRUE.,.TRUE.)
        READ (io_data,IOSTAT=ierr) table1
        name=TRIM(nameunit(io_data))
        CALL closeunit(io_data)
        IF (ierr == 0) then
          write(6,*) 'Read from file '//TRIM(name)
        ELSE
          WRITE(cierr,'(I2)') ierr
          write(6,*) 'READ ERROR ON FILE '//TRIM(name)//' rc='//cierr
        END IF
      END IF
      CALL esmf_bcast(grid,ierr)
      if ( ierr /= 0) call stop_model( 'tracer_ic_soildust: READ ERROR'
     &     , 255 )
      CALL esmf_bcast(grid,table1)

c**** index of table for sub grid scale velocity (sigma) from 0.0001 to 50 m/s
      zsum=0.D0
      DO j=1,Kjm
        IF (j <= 30) THEN
          zsum=zsum+0.0001d0+FLOAT(j-1)*0.00008d0
          x21(j)=zsum
        ELSE IF (j > 30) THEN
          zsum=zsum-0.055254d0+0.005471d0*FLOAT(j)-
     &         1.938365d-4*FLOAT(j)**2.d0+
     &         3.109634d-6*FLOAT(j)**3.d0-
     &         2.126684d-8*FLOAT(j)**4.d0+
     &         5.128648d-11*FLOAT(j)**5.d0
          x21(j)=zsum
        END IF
      END DO
c**** index of table for GCM surface wind speed from 0.0001 to 50 m/s
      x11(:)=x21(:)

c**** prescribed AEROCOM dust emissions
      IF (imDust == 1) THEN

c these netcdf reads are still latlon-specific.
c will call read_dist_data for cubed sphere compatibility

        statusd = nf90_open( 'dust_bin1', nf90_nowrite, ncidd1 )
        statusd = nf90_open( 'dust_bin2', nf90_nowrite, ncidd2 )
        statusd = nf90_open( 'dust_bin3', nf90_nowrite, ncidd3 )
        statusd = nf90_open( 'dust_bin4', nf90_nowrite, ncidd4 )

        statusd = nf90_inq_varid( ncidd1, 'dust', idd1 )
        statusd = nf90_inq_varid( ncidd2, 'dust', idd2 )
        statusd = nf90_inq_varid( ncidd3, 'dust', idd3 )
        statusd = nf90_inq_varid( ncidd4, 'dust', idd4 )

        startd(1)=i_0
        startd(2)=j_0

        countd(1)=1+(i_1-i_0)
        countd(2)=1+(j_1-j_0)
        countd(3)=1

        DO k=1,JDperY

          IF (k > 59) THEN
            startd(3)=k+1
          ELSE
            startd(3)=k
          END IF

          statusd = nf90_get_var( ncidd1, idd1, work, startd, countd )
          d_dust(i_0:i_1,j_0:j_1,1,k)=DBLE(work(i_0:i_1,j_0:j_1))
          statusd = nf90_get_var( ncidd2, idd2, work, startd, countd )
          d_dust(i_0:i_1,j_0:j_1,2,k)=DBLE(work(i_0:i_1,j_0:j_1))
          statusd = nf90_get_var( ncidd3, idd3, work, startd, countd )
          d_dust(i_0:i_1,j_0:j_1,3,k)=DBLE(work(i_0:i_1,j_0:j_1))
          statusd = nf90_get_var( ncidd4, idd4, work, startd, countd )
          d_dust(i_0:i_1,j_0:j_1,4,k)=DBLE(work(i_0:i_1,j_0:j_1))

        END DO

        statusd = nf90_close( ncidd1 )
        statusd = nf90_close( ncidd2 )
        statusd = nf90_close( ncidd3 )
        statusd = nf90_close( ncidd4 )

        CALL write_parallel(' Read from file dust_bin[1-4]',unit=6)

      ELSE IF (imDust == 2) THEN
c**** legacy emission scheme
        if ( im /= 72 .or. jm /= 46 ) call stop_model (
     &       'Stopped in tracer_ic_soildust:' //
     &       ' imDust=2 works only for Im=72 and Jm=46' , 255 )

c**** Read input: threshold speed
        CALL openunit('VTRSH',io_data,.TRUE.,.TRUE.)
        CALL dread_parallel(grid,io_data,nameunit(io_data),vtrsh)
        CALL closeunit(io_data)

c**** Read input: fraction clay
        CALL openunit('FRCLAY',io_data,.TRUE.,.TRUE.)
        CALL dread_parallel(grid,io_data,nameunit(io_data),frclay)
        CALL closeunit(io_data)

c**** Read input: fraction silt
        CALL openunit('FRSILT',io_data,.TRUE.,.TRUE.)
        CALL dread_parallel(grid,io_data,nameunit(io_data),frsilt)
        CALL closeunit(io_data)

c**** Read input: prec-evap data
        CALL openunit('DRYHR',io_data,.TRUE.,.TRUE.)
        CALL dread_parallel(grid,io_data,nameunit(io_data),dryhr)
        CALL closeunit(io_data)

      ELSE IF (imDust == 0) THEN
c**** Probability density function scheme for dust emission

        if (am_i_root()) then
          write(6,*) ' Parameters for soil dust emission:'
          write(6,'(1x,a28,f12.9)') '  Clay: fracClayPDFscheme = '
     &         ,fracClayPDFscheme
          write(6,'(1x,a28,f12.9)') '  Silt: fracSiltPDFscheme = '
     &         ,fracSiltPDFscheme
        end if

c**** Read input: ERS data
        CALL openunit('ERS',io_data,.TRUE.,.TRUE.)
        DO k=1,JMperY
          CALL dread_parallel(grid,io_data,nameunit(io_data),
     &         ers_data(:,:,k))
        END DO
        CALL closeunit(io_data)

c**** Read input: source function data
        call openunit('DSRC',io_data,.true.,.true.)
        call dread_parallel(grid,io_data,nameunit(io_data)
     &       ,dustSourceFunction)
        CALL closeunit(io_data)

c**** Read input: EMISSION LOOKUP TABLE data
        IF (am_i_root()) THEN
          CALL openunit('LKTAB',io_data,.TRUE.,.TRUE.)
          DO k=1,Lkm
            READ(io_data,IOSTAT=ierr) ((table(i,j,k),i=1,Lim),j=1,Ljm)
          END DO
          name=nameunit(io_data)
          CALL closeunit(io_data)
          IF (ierr == 0) THEN
            write(6,*) 'Read from file '//TRIM(name)
          ELSE
            WRITE(cierr,'(I2)') ierr
            write(6,*) ' READ ERROR ON FILE '//TRIM(name)//' rc='//cierr
          END IF
        END IF
        CALL esmf_bcast(grid,ierr)
        if ( ierr /= 0 ) call stop_model (
     &       'tracer_ic_soildust: READ ERROR', 255 )
        CALL esmf_bcast(grid,table)

c**** index of table for threshold velocity from 6.5 to 17 m/s
        DO k=1,Lkm
          x3(k)=6.d0+0.5d0*k
        END DO

c**** index of table for sub grid scale velocity (sigma) from .0001 to 30 m/s
        zsum=0.d0
        DO j=1,Ljm
          IF (j <= 30) THEN
            zsum=zsum+0.0001d0+FLOAT(j-1)*0.00008d0
            x2(j)=zsum
          ELSE IF (j > 30) THEN
            zsum=zsum-0.055254d0+0.005471d0*FLOAT(j)-
     &           1.938365d-4*FLOAT(j)**2.d0+
     &           3.109634d-6*FLOAT(j)**3.d0-
     &           2.126684d-8*FLOAT(j)**4.d0+
     &           5.128648d-11*FLOAT(j)**5.d0
            x2(j)=zsum
          END IF
        END DO
c**** index of table for GCM surface wind speed from 0.0001 to 30 m/s
        x1(:)=x2(:)
      ELSE
        call stop_model ( 'Stopped in tracer_ic_soildust:' //
     &       ' parameterimDUST must be <= 2', 255 )
      END IF

#ifdef TRACERS_MINERALS
!     read mineral fractions from input file
      call read_mineralfractions_netcdf

!     calculate some parameters (weighting of sub clay minerals,
!     effective radii of minerals) for radiation derived from volume
!     distribution of minerals using data by Kandler et al., Tellus B,
!     (2009)
      call calcMineralRadiationParameters

!     apply mineral dependent brittle factor to mineral fractions
!     ATTENTION!!!
!     no brittle factor yet, not clear where to apply in algorithm
!      do m = 1,mtrac
!        minfr( i_0:i_1, j_0:j_1, m ) = brittleFactor( m ) * minfr(
!     &       i_0:i_1, j_0:j_1, m )
!      end do

!     calculate fractions of aggregates between minerals and Iron oxide
!     from mineral fractions at emission
      call calcIronOxideAggregates
#endif /* TRACERS_MINERAL */

#endif /* TRACERS_DUST || TRACERS_MINERALS || TRACERS_AMP || TRACERS_TOMAS */
      RETURN

      end subroutine tracer_ic_soildust


#if (defined TRACERS_DUST) || (defined TRACERS_MINERALS) ||\
    (defined TRACERS_AMP)
c io_trDust
      subroutine io_trDust(kunit,iaction)
!@sum  io_trDust I/O of specific dust aerosol diagnostics (not netcdf)
!@auth Jan Perlwitz
      use domain_decomp_1d, only: pack_data,unpack_data
      implicit none

!@var kunit unit number of read/write
!@var iaction flag for reading or writing to file
      integer,intent(in) :: iaction,kunit

!@var iostat I/O status
      integer :: iostat
!@var header text with information on variables
      character(len=80) :: header

!@var dustDiagSubdd_glob global structured variable of dust aerosol diagnostics
      type(dustDiagSubdd) :: dustDiagSubdd_glob

      allocate(dustDiagSubdd_glob%dustEmission(im,jm,Ntm_dust))
      allocate(dustDiagSubdd_glob%dustEmission2(im,jm,Ntm_dust))
      allocate(dustDiagSubdd_glob%dustDepoTurb(im,jm,Ntm_dust))
      allocate(dustDiagSubdd_glob%dustDepoGrav(im,jm,Ntm_dust))
      allocate(dustDiagSubdd_glob%dustMassInPrec(im,jm,Ntm_dust))
      allocate(dustDiagSubdd_glob%dustSurfMixR(im,jm,Ntm_dust))
      allocate(dustDiagSubdd_glob%dustSurfConc(im,jm,Ntm_dust))
      allocate(dustDiagSubdd_glob%dustMass(im,jm,lm,Ntm_dust))
      allocate(dustDiagSubdd_glob%dustConc(im,jm,lm,Ntm_dust))

      select case(iaction)

      case(:iowrite)            ! write to restart file
        call pack_data(grid,dustDiagSubdd_acc%dustEmission
     &       ,dustDiagSubdd_glob%dustEmission)
        call pack_data(grid,dustDiagSubdd_acc%dustEmission2
     &       ,dustDiagSubdd_glob%dustEmission2)
        call pack_data(grid,dustDiagSubdd_acc%dustDepoTurb
     &       ,dustDiagSubdd_glob%dustDepoTurb)
        call pack_data(grid,dustDiagSubdd_acc%dustDepoGrav
     &       ,dustDiagSubdd_glob%dustDepoGrav)
        call pack_data(grid,dustDiagSubdd_acc%dustMassInPrec
     &       ,dustDiagSubdd_glob%dustMassInPrec)
        call pack_data(grid,dustDiagSubdd_acc%dustSurfMixR
     &       ,dustDiagSubdd_glob%dustSurfMixR)
        call pack_data(grid,dustDiagSubdd_acc%dustSurfConc
     &       ,dustDiagSubdd_glob%dustSurfConc)
        call pack_data(grid,dustDiagSubdd_acc%dustMass
     &       ,dustDiagSubdd_glob%dustMass)
        call pack_data(grid,dustDiagSubdd_acc%dustConc
     &       ,dustDiagSubdd_glob%dustConc)
        header='For subdaily dust tracers diagnostics: dustDiagSubdd'
        if (am_i_root()) then
          write(kunit,iostat=iostat) header
     &         ,dustDiagSubdd_glob%dustEmission
     &         ,dustDiagSubdd_glob%dustEmission2
     &         ,dustDiagSubdd_glob%dustDepoTurb
     &         ,dustDiagSubdd_glob%dustDepoGrav
     &         ,dustDiagSubdd_glob%dustMassInPrec
     &         ,dustDiagSubdd_glob%dustSurfMixR
     &         ,dustDiagSubdd_glob%dustSurfConc
     &         ,dustDiagSubdd_glob%dustMass
     &         ,dustDiagSubdd_glob%dustConc
          if (iostat > 0) call stop_model
     &         ('In io_trdust_drv: Restart file write error',255)
        end if

      case(ioread:)
        select case(iaction)    ! read from restart file
        case(ioread,irerun,irsfic,irsficno) ! restarts
          if (am_i_root()) then
            read(kunit,iostat=iostat) header
     &         ,dustDiagSubdd_glob%dustEmission
     &         ,dustDiagSubdd_glob%dustEmission2
     &         ,dustDiagSubdd_glob%dustDepoTurb
     &         ,dustDiagSubdd_glob%dustDepoGrav
     &         ,dustDiagSubdd_glob%dustMassInPrec
     &         ,dustDiagSubdd_glob%dustSurfMixR
     &         ,dustDiagSubdd_glob%dustSurfConc
     &         ,dustDiagSubdd_glob%dustMass
     &         ,dustDiagSubdd_glob%dustConc
            if (iostat > 0) call stop_model
     &           ('In io trdust_drv: Restart file read error',255)
          end if
          call unpack_data(grid,dustDiagSubdd_glob%dustEmission
     &         ,dustDiagSubdd_acc%dustEmission)
          call unpack_data(grid,dustDiagSubdd_glob%dustEmission2
     &         ,dustDiagSubdd_acc%dustEmission2)
          call unpack_data(grid,dustDiagSubdd_glob%dustDepoTurb
     &         ,dustDiagSubdd_acc%dustDepoTurb)
          call unpack_data(grid,dustDiagSubdd_glob%dustDepoGrav
     &         ,dustDiagSubdd_acc%dustDepoGrav)
          call unpack_data(grid,dustDiagSubdd_glob%dustMassInPrec
     &         ,dustDiagSubdd_acc%dustMassInPrec)
          call unpack_data(grid,dustDiagSubdd_glob%dustSurfMixR
     &         ,dustDiagSubdd_acc%dustSurfMixR)
          call unpack_data(grid,dustDiagSubdd_glob%dustSurfConc
     &         ,dustDiagSubdd_acc%dustSurfConc)
          call unpack_data(grid,dustDiagSubdd_glob%dustMass
     &         ,dustDiagSubdd_acc%dustMass)
          call unpack_data(grid,dustDiagSubdd_glob%dustConc
     &         ,dustDiagSubdd_acc%dustConc)
        end select

      end select

      deallocate(dustDiagSubdd_glob%dustEmission)
      deallocate(dustDiagSubdd_glob%dustEmission2)
      deallocate(dustDiagSubdd_glob%dustDepoTurb)
      deallocate(dustDiagSubdd_glob%dustDepoGrav)
      deallocate(dustDiagSubdd_glob%dustMassInPrec)
      deallocate(dustDiagSubdd_glob%dustSurfMixR)
      deallocate(dustDiagSubdd_glob%dustSurfConc)
      deallocate(dustDiagSubdd_glob%dustMass)
      deallocate(dustDiagSubdd_glob%dustConc)

      return
      end subroutine io_trDust
#endif /* TRACERS_DUST || TRACERS_MINERALS || TRACERS_AMP */

#ifdef NEW_IO
#if (defined TRACERS_DUST) || (defined TRACERS_MINERALS) ||\
    (defined TRACERS_AMP)
c def_rsf_trdust
      subroutine def_rsf_trdust(fid)
!@sum def_rsf_trdust defines control info in restart files specifically for
!@+                  soil dust aerosols
!@auth Jan Perlwitz

      implicit none

!@var fid file id
      integer,intent(in) :: fid

      call defvar(grid,fid,dustDiagSubdd_acc%dustEmission(:,:,:)
     &     ,'dustEmission'//'(dist_im,dist_jm,Ntm_dust)')
      call defvar(grid,fid,dustDiagSubdd_acc%dustEmission2(:,:,:)
     &     ,'dustEmission2'//'(dist_im,dist_jm,Ntm_dust)')
      call defvar(grid,fid,dustDiagSubdd_acc%dustDepoTurb(:,:,:)
     &     ,'dustDepoTurb'//'(dist_im,dist_jm,Ntm_dust)')
      call defvar(grid,fid,dustDiagSubdd_acc%dustDepoGrav(:,:,:)
     &     ,'dustDepoGrav'//'(dist_im,dist_jm,Ntm_dust)')
      call defvar(grid,fid,dustDiagSubdd_acc%dustMassInPrec(:,:,:)
     &     ,' dustMassInPrec'//'(dist_im,dist_jm,Ntm_dust)')
      call defvar(grid,fid,dustDiagSubdd_acc%dustSurfMixR(:,:,:)
     &     ,'dustSurfMixR'//'(dist_im,dist_jm,Ntm_dust)')
      call defvar(grid,fid,dustDiagSubdd_acc%dustSurfConc(:,:,:),'
     &     dustSurfConc'//'(dist_im,dist_jm,Ntm_dust)')
      call defvar(grid,fid,dustDiagSubdd_acc%dustMass(:,:,:,:)
     &     ,'dustMass'//'(dist_im,dist_jm,lm,Ntm_dust)')
      call defvar(grid,fid,dustDiagSubdd_acc%dustConc(:,:,:,:)
     &     ,'dustConc'//'(dist_im,dist_jm,lm,Ntm_dust)')

      return
      end subroutine def_rsf_trdust

c new_io_trdust
      subroutine new_io_trdust(fid,iaction)
!@sum  new_io_trdust netcdf I/O specifically for soil dust aerosols
!@auth Jan Perlwitz

      implicit none

!@var fid file id
!@var iaction flag for reading or writing to file
      integer,intent(in) :: fid,iaction

      select case (iaction)
      case (iowrite)            ! output to restart file
        call write_dist_data(grid,fid,'dustEmission'
     &       ,dustDiagSubdd_acc%dustEmission(:,:,:))
        call write_dist_data(grid,fid,'dustEmission2'
     &       ,dustDiagSubdd_acc%dustEmission2(:,:,:))
        call write_dist_data(grid,fid,'dustDepoTurb'
     &       ,dustDiagSubdd_acc%dustDepoTurb(:,:,:))
        call write_dist_data(grid,fid,'dustDepoGrav'
     &       ,dustDiagSubdd_acc%dustDepoGrav(:,:,:))
        call write_dist_data(grid,fid,'dustMassInPrec'
     &       ,dustDiagSubdd_acc%dustMassInPrec(:,:,:))
        call write_dist_data(grid,fid,'dustSurfMixR'
     &       ,dustDiagSubdd_acc%dustSurfMixR(:,:,:))
        call write_dist_data(grid,fid,'dustSurfConc'
     &       ,dustDiagSubdd_acc%dustSurfConc(:,:,:))
        call write_dist_data(grid,fid,'dustMass'
     &       ,dustDiagSubdd_acc%dustMass(:,:,:,:))
        call write_dist_data(grid,fid,'dustConc'
     &       ,dustDiagSubdd_acc%dustConc(:,:,:,:))
      case (ioread)            ! input from restart file
        call read_dist_data(grid,fid,'dustEmission'
     &       ,dustDiagSubdd_acc%dustEmission(:,:,:))
        call read_dist_data(grid,fid,'dustEmission2'
     &       ,dustDiagSubdd_acc%dustEmission2(:,:,:))
        call read_dist_data(grid,fid,'dustDepoTurb'
     &       ,dustDiagSubdd_acc%dustDepoTurb(:,:,:))
        call read_dist_data(grid,fid,'dustDepoGrav'
     &       ,dustDiagSubdd_acc%dustDepoGrav(:,:,:))
        call read_dist_data(grid,fid,'dustMassInPrec'
     &       ,dustDiagSubdd_acc%dustMassInPrec(:,:,:))
        call read_dist_data(grid,fid,'dustSurfMixR'
     &       ,dustDiagSubdd_acc%dustSurfMixR(:,:,:))
        call read_dist_data(grid,fid,'dustSurfConc'
     &       ,dustDiagSubdd_acc%dustSurfConc(:,:,:))
        call read_dist_data(grid,fid,'dustMass'
     &       ,dustDiagSubdd_acc%dustMass(:,:,:,:))
        call read_dist_data(grid,fid,'dustConc'
     &       ,dustDiagSubdd_acc%dustConc(:,:,:,:))
      end select

      return
      end subroutine new_io_trdust
#endif /* TRACERS_DUST || TRACERS_MINERALS || TRACERS_AMP */
#endif /*NEW_IO*/

#if (defined TRACERS_DUST) || (defined TRACERS_MINERALS) ||\
    (defined TRACERS_AMP)
c accSubddDust
      subroutine accSubddDust(dustDiagSubdd_acc)
!@sum  accSubddDust accumulates specific soil dust aerosol variables for
!@+                 subdaily diagnostics
!@auth Jan Perlwitz

      implicit none

      type(dustDiagSubdd),intent(inout) :: dustDiagSubdd_acc

      integer :: l,n,n1

!$OMP PARALLEL DO PRIVATE (l,n,n1)
      do n=1,Ntm_dust
        n1=n_soilDust+n-1
        dustDiagSubdd_acc%dustEmission(:,:,n)
     &       =dustDiagSubdd_acc%dustEmission(:,:,n)+dust_flux_glob(:,:,n
     &       )
        dustDiagSubdd_acc%dustEmission2(:,:,n)
     &       =dustDiagSubdd_acc%dustEmission(:,:,n)+dust_flux2_glob(:,:
     &       ,n)
#ifdef TRACERS_DRYDEP
        if (dodrydep(n1)) then
          dustDiagSubdd_acc%dustDepoTurb(:,:,n)
     &         =dustDiagSubdd_acc%dustDepoTurb(:,:,n)
     &         +sum(depo_turb_glob(:,:,:,n1),dim=3)
          dustDiagSubdd_acc%dustDepoGrav(:,:,n)
     &         =dustDiagSubdd_acc%dustDepoGrav(:,:,n)
     &         +sum(depo_grav_glob(:,:,:,n1),dim=3)
        end if
#endif
#ifdef TRACERS_WATER
        if (dowetdep(n1)) then
          dustDiagSubdd_acc%dustMassInPrec(:,:,n)
     &         =dustDiagSubdd_acc%dustMassInPrec(:,:,n)+trprec(n1,:,:)
        end if
#else
        dustDiagSubdd_acc%dustMassInPrec(:,:,n)
     &       =dustDiagSubdd_acc%dustMassInPrec(:,:,n)+trprec_dust(n,:,:)
#endif
        dustDiagSubdd_acc%dustSurfMixR(:,:,n)
     &       =dustDiagSubdd_acc%dustSurfMixR(:,:,n)+trcSurf(:,:,n1)
        dustDiagSubdd_acc%dustSurfConc(:,:,n)
     &       =dustDiagSubdd_acc%dustSurfConc(:,:,n)+trcSurfByVol(:,:,n1)
        dustDiagSubdd_acc%dustMass(:,:,:,n)=dustDiagSubdd_acc%dustMass(:
     &       ,:,:,n)+trm(:,:,:,n1)
        do l=1,lm
          dustDiagSubdd_acc%dustConc(:,:,l,n) =
     &         dustDiagSubdd_acc%dustConc(:,:,l,n) + trm(:,:,l,n1)
     &         *byam(l,:,:)*1d2*pmid(l,:,:)/(rgas*t(:,:,l)*pk(l,:,:))
        end do
      end do
!$OMP END PARALLEL DO

      return
      end subroutine accSubddDust
#endif /* TRACERS_DUST || TRACERS_MINERALS || TRACERS_AMP */

#ifdef TRACERS_MINERALS
c read_mineralfractions_netcdf
      subroutine read_mineralfractions_netcdf
!@sum read_mineralfractions_netcdf reads mineral fractions from input file
!@auth jan perlwitz

      implicit none

      character( len = 28 ), parameter :: rstring =
     &     'read_mineralfractions_netcdf'

      logical, dimension(ntm_dust) :: qminfr = .false.

      integer :: i, j, n, n1, ncid, varid
      integer :: count(2), start(2)

      character( len=4 ) :: minName
      character( len=5 ) :: binName
      character( len=13 ) :: varName

      real(kind=8), dimension( grid%i_strt:grid%i_stop,
     &                 grid%j_strt:grid%j_stop ) :: work ! no halo

!      call get( grid, j_strt=j_0, j_stop=j_1, i_strt=i_0, i_stop=i_1 )

      if ( am_i_root() ) write( 6, * ) 'Read from file MINFR'

      call check_netcdf( nf90_open( 'MINFR', nf90_nowrite, ncid ),
     &     'nf90_open called from ' // rstring // ' in TRDUST_DRV.f' )

      start( 1 ) = i_0
      start( 2 ) = j_0

      count( 1 ) = 1 + ( i_1 - i_0 )
      count( 2 ) = 1 + ( j_1 - j_0 )


      mineralFractions = 0.d0
      do n = 1,Ntm_dust

        select case ( dust_names( n )(5:8) )

        case('Illi','Kaol','Smec','Calc','Quar','Feld','Hema','Gyps')

          minName = dust_names( n )(5:8)
          if ( trim( minName ) == 'Hema' ) minName = 'Feox'

        case default
          cycle
          
        end select

        select case ( dust_names( n )(1:4) )

        case('Clay')
          binName = 'Clay'
        case('Sil1')
          binName = 'Silt1'
        case('Sil2')
          binName = 'Silt2'
        case('Sil3')
          binName = 'Silt3'
#ifdef TRACERS_DUST_Silt4
        case('Sil4')
          binName = 'Silt4'
#ifdef TRACERS_DUST_Silt5
        case('Sil5')
          binName = 'Silt5'
#endif
#endif
        case default
          cycle
        end select

        varName='frac' // trim( binName ) // trim( minName )

        if ( am_i_root()) write( 6, * ) '  read mineral fraction: ',
     &       trim( varName )

        call check_netcdf( nf90_inq_varid ( ncid, trim( varName ), varid
     &       ), 'nf90_inq_varid called from ' // rstring //
     &       ' in TRDUST_DRV.f' )

        call check_netcdf( nf90_get_var ( ncid, varid, work, start,
     &       count ), 'nf90_get_var called from ' // rstring //
     &       ' in TRDUST_DRV.f' )

        mineralFractions( i_0:i_1, j_0:j_1, n ) = max( work( i_0:i_1,
     &       j_0:j_1 ), 0.d0 )

      end do                    ! Ntm_dust


      call check_netcdf( nf90_close( ncid ), 'nf90_close called ' //
     &     'from ' // rstring // ' in TRDUST_DRV.f' )

c**** scale total mass of mineral fraction input to 1 between 0.1 and 32 um
c**** (between 0.1 and 16 um, if Silt4 class is not defined) for each grid box
c**** so that a possible different scaling of the input mineral fractions from
c**** different files does not influence the results
      n1 = ntm_clay + ntm_sil1 + ntm_sil2 + ntm_sil3 + ntm_sil4
      work( i_0:i_1, j_0:j_1 ) = sum( mineralFractions( i_0:i_1, j_0:j_1
     &     , 1:n1 ), dim=3 )
      do j = j_0,j_1
        do i = i_0,i_1
          if ( work( i, j ) > 0.d0 ) then
            mineralFractions( i, j, : ) =
     &           mineralFractions( i, j, : ) / work( i, j )
          else
            mineralFractions( i, j, : ) = 0.d0
          end if
        end do
      end do

      return
      end subroutine read_mineralfractions_netcdf

c calcMineralRadiationParameters
      subroutine calcMineralRadiationParameters
!@sum calcMineralRadiationParameters  calculates mineral tracers missing
!@+     in the clay or silt size class in Claquin's MMT, using as constraint
!@+     the volume fractions of minerals and size distribution information
!@+     provided by Kandler et al., Tellus B (2009)
!@auth jan perlwitz

      implicit none

!@param nDistrModes  number of modes in particle density distributions
      integer, parameter :: nDistrModes = 4
!@var modeParams_n number distribution parameters n
!@var modeParams_m number distribution parameters m
!@var modeParams_zeta number distribution parameters zeta
      real(kind=8), dimension( nDistrModes ) :: modeParams_n,
     &     modeParams_m, modeParams_zeta

!@param nBinsK  number of aerosol bins in Kandler data set
      integer, parameter :: nBinsK = 10
!@param binsK  array with boundaries of bins in Kandler data set [1 um]
      real(kind=8), parameter, dimension( nBinsK+1 ) :: binBoundsK = (/
     &     0.1d0, 0.25d0, 0.5d0, 1.d0, 2.5d0, 5.d0, 10.d0, 25.d0, 50.d0
     &     , 100.d0, 250.d0 /)

!@param claySiltBounds  boundaries for calculations of mass fractions in
!@+       clay and silt from ratios
      real(kind=8), parameter, dimension( 3 ) :: claySiltBounds = (/
     &     0.1d0, 2.d0, 50.d0 /)

!@var lnGeomMeanDiameter  natural logarithm of geometrical mean diameter
      real(kind=8), dimension( nBinsK ) :: lnGeomMeanDiameter
!@var numberDensityDistrModes  array with number density distribution values
      real(kind=8), dimension( nBinsK ) :: numberDensityDistrModes
!@var surfaceIncrementsK  array with particle surface area increments
!@+     in Kandler size bins
      real(kind=8), dimension( nBinsK ) :: surfaceIncrementsK
!@var volumeIncrementsK  array with particle volume increments in Kandler
!@+     size bins
      real(kind=8), dimension( nBinsK ) :: volumeIncrementsK

!@var volumeFractionsMinerals  array with volume fractions of minerals
      real(kind=8), dimension( nMinerals, nBinsK ) ::
     &     volumeFractionsMinerals
!@var volumeIncrementsMinerals array with volume increments of minerals after
!@+     multplication with size distribution
      real(kind=8), dimension( nMinerals, nBinsK ) ::
     &     volumeIncrementsMinerals
!@var binsKtoClaySilt  transformation matrix for mapping the Kandler bins
!@+     on to clay and the silt range used for calculating volume ratios
      real(kind=8), dimension( nBinsK, 2 ) :: binsKtoClaySilt
!@var volumeClaySiltMinerals mineral volume increments for clay size and
!@+     the silt size range 2 to 50 um used for calculating volume ratios
      real(kind=8), dimension( nMinerals, 2 ) ::
     &     volumeClaySiltMinerals

!@var binsKtoSubClay  transformation matrix for mapping Kandler data size
!@+     bins to Clay sub bins

      real(kind=8), dimension( nBinsK, nSubClays ) :: binsKtoSubClay
!@var volumeIncrementsMineralsSubClay  volume increments of minerals mapped
!@+     ModelE sub bins of clay
      real(kind=8), dimension( nMinerals, nSubClays ) ::
     &     volumeIncrementsMineralsSubClay

!@var binsKtoDustBinsRadia  transformation matrix for mapping Kandler data
!@+     size bins to radiation dust bins
      real(kind=8), dimension( nBinsK, nDustBinsRadia ) ::
     &     binsKtoDustBinsRadia
!@var effRadiusMineralsK  effective radius of particles in Kandler data size
!+      bins
      real(kind=8), dimension( nBinsK ) :: effRadiusMineralsK

      integer :: i

c**** get natural logarithm of geometric mean diameter of the size bins,
c**** the average dust number density distribution over the particle
c**** diameter (both not used)
      call getLnGeomMeanDiameter( binBoundsK, lnGeomMeanDiameter )
      call getNumberDensityDistrModes( nDistrModes, binBoundsK,
     &     numberDensityDistrModes )

c**** calculate particle surface increments for Kandler dust size bins
      call calcSurfaceIncrements( nDistrModes, binBoundsK,
     &     surfaceIncrementsK )
c**** calculate particle volume increments for Kandler dust size bins
      call calcVolumeIncrements( nDistrModes, binBoundsK,
     &     volumeIncrementsK )

c**** retrieve mineral fractions in Kandler size bins from data base
      call getVolumeFractionsMinerals

c**** calculate volume increments of each tracer in each size bin by
c**** multiplying the volume fractions in the size bins (which are
c**** normalized to add up to 1 over all minerals in each size bin) with
c**** the average dust number density distribution
      do i = 1,nMinerals
        volumeIncrementsMinerals( i, 1:nBinsK ) =
     &       volumeFractionsMinerals( i, 1:nBinsK ) * volumeIncrementsK(
     &       1:nBinsK )
!        write(999,*) 'In TRDUST_DRV.f: In calcMineralRadiationParameters: ',
!     &       'nMinerals, i, volumeIncrementsMinerals( i, 1:nBinsK ): '
!     &       , nMinerals, i, volumeIncrementsMinerals( i, 1:nBinsK )
      end do

c**** get tranformation matrix for mapping Kandler bins onto clay (0.1 -
c**** 2 um ) and silt range (2 - 50 um) used for calculating new mineral
c**** fractions
      call getBins1toBins2_ln( binBoundsK, claySiltBounds,
     &     binsKtoClaySilt )

c**** calculate volume in clay range (0.1 - 2 um ) and silt range
c**** (2 - 50 um) used for calculating new volume fractions
      volumeClaySiltMinerals = matmul( volumeIncrementsMinerals,
     &     binsKtoClaySilt )
C$$$      do i = 1,nMinerals
C$$$        write( 999, * )
C$$$     &       'In TRDUST_DRV.f: In calcMineralRadiationParameters: '
C$$$     &       ,'nMinerals, i, volumeClaySiltMinerals( i, 1:2 ): '
C$$$     &       ,nMinerals, i, volumeClaySiltMinerals( i, : )
C$$$      end do

c**** get transformation matrix for mapping Kandler data size bins on to
c**** ModelE clay sub bins
      call getBins1toBins2_ln( binBoundsK, subClayBounds, binsKtoSubClay
     &     )

c**** map volume increments of minerals from Kandler data size bins onto
c**** the sub bins of clay in ModelE (used in radiation calculations)
      volumeIncrementsMineralsSubClay = matmul( volumeIncrementsMinerals
     &     , binsKtoSubClay )

C$$$      do i = 1,nMinerals
C$$$        write( 999, * )
C$$$     &       'In TRDUST_DRV.f: In calcMineralRadiationParameters: '
C$$$     &       ,'nMinerals, i, nSubClays, '
C$$$     &       ,'volumeIncrementsMineralsSubClay: ' , nMinerals, i
C$$$     &       ,nSubClays, volumeIncrementsMineralsSubClay( i,1:nSubClays)
C$$$      end do

c**** calculate normalized mass fraction weights of the minerals for
c**** each sub clay bin
      call calcSubClayWeights

c**** get transformation matrix for mapping from Kandler dust size bins
c**** to ModelE radiation code dust aerosols bins
      call getBins1toBins2_ln( binBoundsK, dustBoundsRadia,
     &     binsKtoDustBinsRadia )

c**** calculate effective radius from volume and cross sectional area with
c**** cross sectional area = surfaceIncrements / 4. and radius = diameter / 2.
      effRadiusMineralsK( 1:nBinsK ) = volumeIncrementsK( 1:nBinsK) /
     &     surfaceIncrementsK( 1:nBinsK ) / 8.d0

!      write(999,*) 'In TRDUST_DRV.f: In calcMineralRadiationParameters: ',
!     &     'surfaceIncrementsK: ', surfaceIncrementsK
!      write(999,*) 'In TRDUST_DRV.f: In calcMineralRadiationParameters: ',
!     &     'volumeIncrementsK: ', volumeIncrementsK
!      write(999,*) 'In TRDUST_DRV.f: In calcMineralRadiationParameters: ',
!     &     'effRadiusMineralsK: ', effRadiusMineralsK

      if ( calcEffectiveRadius == 1 ) then

c**** map effective radii onto radiation code dust size bins
        effRadMinerals = matmul( effRadiusMineralsK,
     &       binsKtoDustBinsRadia )

      end if

!      write(999,*) 'In TRDUST_DRV.f: In calcMineralRadiationParameters: ',
!     &     'effRadMinerals: ', effRadMinerals

      return

      contains

c getLnGeomMeanDiameter
      subroutine getLnGeomMeanDiameter( binBoundsK, lnGeomMeanDiameter )
!@sum getLnGeomMeanDiameter  calculates natural logarithm of geometric
!@+     mean diameters of size bins
!@auth jan perlwitz

      implicit none

      real(kind=8), intent(in) :: binBoundsK(:)
      real(kind=8), intent(out) :: lnGeomMeanDiameter(
     &     size( binBoundsK(:) ) - 1 )

      integer :: ib, nbins

      nbins = size( binBoundsK ) - 1

      do ib = 1,nbins
        lnGeomMeanDiameter( ib ) = 0.5d0 * (log( binBoundsK( ib ) ) +
     &       log( binBoundsK( ib+1 ) ))
      end do

!      write(999,*) 'In TRDUST_DRV.f: In getLnGeomMeanDiameter: ',
!     &     'nBinsK, lnGeomMeanDiameter: ', nBinsK, lnGeomMeanDiameter

      return
      end subroutine getLnGeomMeanDiameter

c getNumberDensityDistrModes
      subroutine getNumberDensityDistrModes( nDistrModes, diameters,
     &     numberDensityDistrModes )
!@sum getNumberDensityDistrModes  gets values of number density distribution
!@+     over a range of particle diameters
!@auth jan perlwitz

      implicit none

!@var nDistrModes  input: number of particle density distribution modes
      integer, intent(in) :: nDistrModes
!@var lnDiameters  input: array with particle diameters
      real(kind=8), intent(in) :: diameters(:)
!@var numberDensityDistrModes  output: number density distribution values
      real(kind=8), intent(out) :: numberDensityDistrModes(
     &     size( diameters(:) ), nDistrModes )

      integer :: id, im, ndiam
      real(kind=8) :: pi

      pi = 4.d0 * atan( 1.d0 )

      ndiam = size( diameters )

      call getModeParams

      do im = 1,nDistrModes
        do id = 1,ndiam
          numberDensityDistrModes( id, im ) = modeParams_n( im ) / log(
     &         modeParams_zeta( im ) ) * exp( -(log( diameters( id ) /
     &         modeParams_m( im ) ))**2 / (2.d0 * (log( modeParams_zeta(
     &         im ) ) )**2) ) / sqrt( 2.d0 * pi )
        end do
      end do

!      do im = 1,nDistrModes
!        write(999,*) 'In TRDUST_DRV.f: In NumberDensityDistrModes: ',
!     &       'im, NumberDensityDistrModes: ', im,
!     &       numberDensityDistrModes( :, im )
!      end do

      return
      end subroutine getNumberDensityDistrModes

c calcSurfaceIncrements
      subroutine calcSurfaceIncrements( nDistrModes, diameters,
     &     surfaceIncrements )
!@sum calcSurfaceIncrements  calculate surface increments between two diameters
!@+     of number density distribution using number size distribution
!@+     parameters according to Seinfeld and Pandis, Wiley, 1998, p. 425f
!@+     and error function
!@auth jan perlwitz

      implicit none

!@var nDistrModes  input: number of particle density distribution modes
      integer, intent(in) :: nDistrModes
!@var lnDiameters  input: array with particle diameters
      real(kind=8), intent(in) :: diameters(:)
!@var surfaceIncrements  output: surface increments between diameter values
      real(kind=8), intent(out) :: surfaceIncrements(
     &     size( diameters(:) ) - 1 )

      integer :: id, im, ndiam
      real(kind=8) :: z0, z1, errfz0, errfz1
      real(kind=8) :: work( size( diameters(:) ) - 1, nDistrModes )

      ndiam = size( diameters )

      call getModeParams

      work = 0.d0
      do im = 1,nDistrModes

        do id = 1,ndiam-1

          z0 = (log( diameters( id ) / modeParams_m( im ) ) - 2.d0 *
     &         (log( modeParams_zeta( im ) ) )**2 ) / (sqrt( 2.d0 ) *
     &         modeParams_zeta( im ))
          z1 = (log( diameters( id+1 ) / modeParams_m( im ) ) - 2.d0 *
     &         (log( modeParams_zeta( im ) ) )**2 ) / (sqrt( 2.d0 ) *
     &         modeParams_zeta( im ))
          errfz0 = errorFunction( z0 )
          errfz1 = errorFunction( z1 )
          work( id, im ) = modeParams_n( im ) * exp( 2.d0 * log(
     &         modeParams_m( im ) ) + 2.d0 * (log( modeParams_zeta(im )
     &         ))**2 ) * (errfz1 - errfz0) / 2.d0

!          write(999,*) 'In TRDUST_DRV.f: In calcSurfaceIncrements: ',
!     &         'diameters(id), z0, errfz0, diameters(id+1), z1, ' ,
!     &         'erffz1, work(id,im): ', diameters( id ), z0, errfz0,
!     &         diameters(id+1), z1, errfz1, work( id, im )

        end do
        
!        write(999,*) 'In TRDUST_DRV.f: In calcSurfaceIncrements: ',
!     &       'im, diameters(1:ndiam), work(1:ndiam-1, im): ', im,
!     &       diameters, work(1:ndiam-1, im)

      end do

      surfaceIncrements( 1:ndiam-1 ) = sum( work( 1:ndiam-1, : ), dim=2
     &     )

!      write(999,*) 'In TRDUST_DRV.f: In calcSurfaceIncrements: ',
!     &     'diameters, surfaceIncrements: ', diameters,
!     &     surfaceIncrements

      return
      end subroutine calcSurfaceIncrements

c calcVolumeIncrements
      subroutine calcVolumeIncrements( nDistrModes, diameters,
     &     volumeIncrements )
!@sum calcVolumeIncrements  calculate volume increments between two diameters
!@+     of number density distribution using number size distribution
!@+     parameters according to Seinfeld and Pandis, Wiley, 1998, p. 425f
!@+     and error function
!@auth jan perlwitz

      implicit none

!@var nDistrModes  input: number of particle density distribution modes
      integer, intent(in) :: nDistrModes
!@var lnDiameters  input: array with particle diameters
      real(kind=8), intent(in) :: diameters(:)
!@var volumeIncrements  output: volume increments between diameter values
      real(kind=8), intent(out) :: volumeIncrements(
     &     size( diameters(:) ) - 1 )

      integer :: id, im, ndiam
      real(kind=8) :: z0, z1, errfz0, errfz1
      real(kind=8) :: work( size( diameters(:) ) - 1, nDistrModes )

      ndiam = size( diameters )

      call getModeParams

      work = 0.d0
      do im = 1,nDistrModes

        do id = 1,ndiam-1

          z0 = (log( diameters( id ) / modeParams_m( im ) ) - 3.d0 *
     &         (log( modeParams_zeta( im ) ) )**2 ) / (sqrt( 2.d0 ) *
     &         modeParams_zeta( im ))
          z1 = (log( diameters( id+1 ) / modeParams_m( im ) ) - 3.d0 *
     &         (log( modeParams_zeta( im ) ) )**2 ) / (sqrt( 2.d0 ) *
     &         modeParams_zeta( im ))
          errfz0 = errorFunction( z0 )
          errfz1 = errorFunction( z1 )
          work( id, im ) = modeParams_n( im ) * exp( 3.d0 * log(
     &         modeParams_m( im ) ) + 9.d0 / 2.d0 * (log(
     &         modeParams_zeta( im ) ))**2) * (errfz1 - errfz0) / 2.d0

!          write(999,*) 'In TRDUST_DRV.f: In calcVolumeIncrements: ',
!     &         'diameters(id), z0, errfz0, diameters(id+1), z1, ' ,
!     &         'erffz1, work(id,im): ', diameters( id ), z0, errfz0,
!     &         diameters(id+1), z1, errfz1, work( id, im )

        end do
        
!        write(999,*) 'In TRDUST_DRV.f: In calcVolumeIncrements: ',
!     &       'im, diameters(1:ndiam), work(1:ndiam-1, im): ', im,
!     &       diameters, work(1:ndiam-1, im)

      end do

      volumeIncrements( 1:ndiam-1 ) = sum( work( 1:ndiam-1, : ), dim=2 )

!      write(999,*) 'In TRDUST_DRV.f: In calcVolumeIncrements: ',
!     &     'diameters, volumeIncrements: ', diameters, volumeIncrements

      return
      end subroutine calcVolumeIncrements

c getModeParams
      subroutine getModeParams
!@sum getModeParams  get parameters of lognormal density distribution
!@auth jan perlwitz

      implicit none

      character(len=3) :: cpar = ''

      select case( soilDustEmissionDistr )

      case( 0 )

! Kandler et al., Tellus B, (2009)
! Medium to low dust
! i =                      1          2          3          4
        modeParams_n = (/ 497.1d0, 72.33d0, 20.64d0, 0.002031d0 /)
        modeParams_m = (/ 0.08542d0, 0.03529d0, 0.7342d0, 31.08d0 /)
        modeParams_zeta = (/ 1.898d0, 5.208d0, 1.749d0, 2.486d0 /)

      case( 1 )

! Kandler et al., Tellus B, (2009)
! High dust
! i =                      1          2          3          4
        modeParams_n = (/ 367.8d0, 117.9d0, 3.839d0, 0.03189d0 /)
        modeParams_m = (/ 0.07061d0, 0.7443d0, 1.732d0, 153.9d0 /)
        modeParams_zeta = (/ 2.020d0, 1.791d0, 3.718d0, 1.381d0 /)

      case default

        write( cpar, '(i3) ' )
        call stop_model( ' In TRDUST_DRV.f: In getModeParams: ' //
     &       'soilDustEmissionDistr /= 0 or 1. It is ' // cpar, 255 )

      end select

      return
      end subroutine getModeParams

c getVolumeFractionsMinerals
      subroutine getVolumeFractionsMinerals
!@sum getVolumeFractionsMinerals  volume fraction of minerals
!@+     in each size bin from volume fractions by Kandler et al.,
!@+     TellusB (2009) used to determine mass ratios between size bins
!@auth jan perlwitz

      implicit none

      integer :: n, n1

      volumeFractionsMinerals = 0.d0

      do n = 1,nMinerals

        select case ( mineralNames( n ) )

        case('Illi')
          volumeFractionsMinerals( n, : ) = (/ 0.16d0, 0.169d0, 0.23d0,
     &         0.243d0, 0.257d0, 0.262d0, 0.261d0, 0.256d0, 0.201d0,
     &         0.161d0 /)

        case('Kaol')
          volumeFractionsMinerals( n, : ) = (/ 0.031d0, 0.033d0, 0.045d0
     &         , 0.047d0, 0.05d0, 0.051d0, 0.051d0, 0.050d0, 0.039d0,
     &         0.031d0 /)

        case('Smec')
          volumeFractionsMinerals( n, : ) = (/ 0.16d0, 0.169d0, 0.23d0,
     &         0.243d0, 0.257d0, 0.262d0, 0.261d0, 0.256d0, 0.201d0,
     &         0.161d0 /)
                            ! 'Same as Illite because of mixed layer I/S'

        case('Calc')
          volumeFractionsMinerals( n, : ) = (/ 0.018d0, 0.02d0, 0.085d0,
     &         0.096d0, 0.114d0, 0.114d0, 0.087d0, 0.061d0, 0.019d0,
     &         0.003d0 /)
                                            ! Calcite + Dolomite
        case('Quar')
          volumeFractionsMinerals( n, : ) = (/ 0.029d0, 0.013d0, 0.098d0
     &         ,0.109d0, 0.101d0, 0.111d0, 0.147d0, 0.211d0, 0.446d0
     &         ,0.566d0 /)

        case('Feld')
          volumeFractionsMinerals( n, : ) = (/ 0.172d0, 0.182d0, 0.246d0
     &         , 0.262d0, 0.276d0, 0.282d0, 0.28d0, 0.275d0, 0.216d0,
     &         0.173d0/)
                                            ! Potassium Feldspar + Plagioclase

        case('Feox')
          volumeFractionsMinerals( n, : ) = (/ 0.006d0, 0.005d0, 0.007d0
     &         , 0.008d0, 0.006d0, 0.007d0, 0.007d0, 0.008d0, 0.006d0,
     &         0.007d0 /)
                                            ! derived from total iron content

        case('Gyps')
          volumeFractionsMinerals( n, : ) = (/ 0.004d0, 0.008d0, 0.05d0, 
     &         0.025d0, 0.04d0, 0.03d0, 0.026d0, 0.001d0, 0.001d0,
     &         0.000d0 /)
        case default
          cycle

        end select

C$$$        if ( am_i_root() ) write( 999, * )
C$$$     &       'In TRDUST_DRV.f: In getVolumeFractionsMinerals: ',
C$$$     &       'nMinerals, n, volumeFractionsMinerals( n , : ): ',
C$$$     &       nMinerals, n, volumeFractionsMinerals( n, : )

      end do

      mineralIndex = 0
      do n = 1,nMinerals

        select case ( mineralNames( n ) )

        case('Illi')
          mineralIndex( n_clayilli - n_soilDust + 1 ) = n
          mineralIndex( n_sil1illi - n_soilDust + 1 ) = n
          mineralIndex( n_sil2illi - n_soilDust + 1 ) = n
          mineralIndex( n_sil3illi - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt4
          mineralIndex( n_sil4illi - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt5
          mineralIndex( n_sil5illi - n_soilDust + 1 ) = n
#endif
#endif

        case('Kaol')
          mineralIndex( n_claykaol - n_soilDust + 1 ) = n
          mineralIndex( n_sil1kaol - n_soilDust + 1 ) = n
          mineralIndex( n_sil2kaol - n_soilDust + 1 ) = n
          mineralIndex( n_sil3kaol - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt4
          mineralIndex( n_sil4kaol - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt5
          mineralIndex( n_sil5kaol - n_soilDust + 1 ) = n
#endif
#endif

        case('Smec')
          mineralIndex( n_claysmec - n_soilDust + 1 ) = n
          mineralIndex( n_sil1smec - n_soilDust + 1 ) = n
          mineralIndex( n_sil2smec - n_soilDust + 1 ) = n
          mineralIndex( n_sil3smec - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt4
          mineralIndex( n_sil4smec - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt5
          mineralIndex( n_sil5smec - n_soilDust + 1 ) = n
#endif
#endif

        case('Calc')
          mineralIndex( n_claycalc - n_soilDust + 1 ) = n
          mineralIndex( n_sil1calc - n_soilDust + 1 ) = n
          mineralIndex( n_sil2calc - n_soilDust + 1 ) = n
          mineralIndex( n_sil3calc - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt4
          mineralIndex( n_sil4calc - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt5
          mineralIndex( n_sil5calc - n_soilDust + 1 ) = n
#endif
#endif

        case('Quar')
          mineralIndex( n_clayquar - n_soilDust + 1 ) = n
          mineralIndex( n_sil1quar - n_soilDust + 1 ) = n
          mineralIndex( n_sil2quar - n_soilDust + 1 ) = n
          mineralIndex( n_sil3quar - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt4
          mineralIndex( n_sil4quar - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt5
          mineralIndex( n_sil5quar - n_soilDust + 1 ) = n
#endif
#endif

        case('Feld')
          mineralIndex( n_clayfeld - n_soilDust + 1 ) = n
          mineralIndex( n_sil1feld - n_soilDust + 1 ) = n
          mineralIndex( n_sil2feld - n_soilDust + 1 ) = n
          mineralIndex( n_sil3feld - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt4
          mineralIndex( n_sil4feld - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt5
          mineralIndex( n_sil5feld - n_soilDust + 1 ) = n
#endif
#endif

        case('Feox')
          mineralIndex( n_clayhema - n_soilDust + 1 ) = n
          mineralIndex( n_sil1hema - n_soilDust + 1 ) = n
          mineralIndex( n_sil2hema - n_soilDust + 1 ) = n
          mineralIndex( n_sil3hema - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt4
          mineralIndex( n_sil4hema - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt5
          mineralIndex( n_sil5hema - n_soilDust + 1 ) = n
#endif
#endif

        case('Gyps')
          mineralIndex( n_claygyps - n_soilDust + 1 ) = n
          mineralIndex( n_sil1gyps - n_soilDust + 1 ) = n
          mineralIndex( n_sil2gyps - n_soilDust + 1 ) = n
          mineralIndex( n_sil3gyps - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt4
          mineralIndex( n_sil4gyps - n_soilDust + 1 ) = n
#ifdef TRACERS_DUST_Silt5
          mineralIndex( n_sil5gyps - n_soilDust + 1 ) = n
#endif
#endif

        case default
          cycle

        end select

      end do

C$$$      if ( am_i_root() ) write( 999, * )
C$$$     &     'In getVolumeFractionsMinerals: mineralIndex: ', mineralIndex

      return
      end subroutine getVolumeFractionsMinerals

c getBins1toBins2_ln
      subroutine getBins1toBins2_ln( bounds1, bounds2, bins1toBins2 )
!@sum getBins1toBins2_ln  gets logarithmic transformation matrix for mapping
!@+     size bins of dimension nbins1, with boundaries bounds1 to size bins
!@+     of dimension nbins2, with boundaries bounds2
!@auth jan perlwitz

      implicit none

      real(kind=8), intent(in) :: bounds1(:), bounds2(:)
      real(kind=8), intent(out) :: bins1toBins2(:,:)

      integer :: i, j, nbins1, nbins2

      nbins1 = size( bounds1 ) - 1
      nbins2 = size( bounds2 ) - 1

!      write(999,*) 'In TRDUST_DRV.f: In getBins1toBins2_ln: ',
!     &     'nbins1, bounds1, nbins2, bounds2: ' , nbins1, bounds1,
!     &     nbins2, bounds2

      bins1toBins2 = 0.d0
      do j = 1,nbins2
        do i = 1,nbins1

!          write(999,*) 'In TRDUST_DRV.f: In getBins1toBins2_ln:'
!          write(999,*) ' i, bounds1(i), bounds1(i+1): ', i, bounds1( i )
!     &         , bounds1( i+1 )
!          write(999,*) ' j, bounds2(j), bounds2(j+1): ', j, bounds2( j )
!     &         , bounds2( j+1 )

          if ( bounds1( i+1 ) < bounds2( j ) .or. bounds1( i ) >
     &         bounds2( j+1 ) ) then
!            write(999,*) 'cycle'
            cycle
          end if

          if ( bounds1( i+1 ) >= bounds2( j ) .and. bounds1( i+1 ) <=
     &         bounds2( j+1 ) ) then
            if ( bounds1( i ) < bounds2( j ) ) then
              bins1toBins2( i, j ) = log( bounds1( i+1 ) / bounds2( j )
     &             ) / log( bounds1( i+1 ) / bounds1( i ) )
            else
              bins1toBins2( i, j ) = 1.d0
            end if
          else if ( bounds1( i+1 ) > bounds2( j+1 ) .and. bounds1( i )
     &           >= bounds2( j ) ) then
            bins1toBins2( i, j ) = log( bounds2( j+1 ) / bounds1( i ) )
     &           / log( bounds1( i+1 ) / bounds1( i ) )
          else
            bins1toBins2( i, j ) = log( bounds2( j+1 ) / bounds2( j ) )
     &           / log( bounds1( i+1 ) / bounds1( i ) )
          end if

        end do
!        write(999,*) 'In TRDUST_DRV.f: In getBins1toBins2_ln: ',
!     $       'j, bins1toBins2(:,j): ' , j, bins1toBins2(:,j)
      end do

      return
      end subroutine getBins1toBins2_ln

c calcSubClayWeights
      subroutine calcSubClayWeights
!@sum calcSubClayWeights  calculate weights of masses in each clay sub bin
!@+     for each tracer
!@auth jan perlwitz

      implicit none

      integer :: n, n_hema, n_aggr
      real(kind=8) :: zsum

      subClayWeights = 0.d0
      do n = 1,ntm_dust

        select case( dust_names( n ) )

        case('ClayIlli','ClayKaol','ClaySmec','ClayCalc','ClayQuar'
     &         ,'ClayFeld','ClayGyps')
          n_hema = n_clayhema - n_soilDust + 1
          select case ( dust_names( n ) )
          case('ClayIlli') ; n_aggr = n_clayilhe - n_soilDust + 1
          case('ClayKaol') ; n_aggr = n_claykahe - n_soilDust + 1
          case('ClaySmec') ; n_aggr = n_claysmhe - n_soilDust + 1
          case('ClayCalc') ; n_aggr = n_claycahe - n_soilDust + 1
          case('ClayQuar') ; n_aggr = n_clayquhe - n_soilDust + 1
          case('ClayFeld') ; n_aggr = n_clayfehe - n_soilDust + 1
          case('ClayGyps') ; n_aggr = n_claygyhe - n_soilDust + 1
          end select

        case default
          cycle

        end select

C$$$        if ( am_i_root() ) write( 999, * )
C$$$     &       'In calcSubClayWeights: n, dust_names( n ), ',
C$$$     &       'mineralIndex( n ), n_hema, n_aggr: ', n, dust_names( n ),
C$$$     &       mineralIndex( n ), n_hema, n_aggr

        do i = 1,nSubClays

          subClayWeights( n, i ) = volumeIncrementsMineralsSubClay(
     &         mineralIndex( n ), i) / volumeClaySiltMinerals(
     &         mineralIndex( n ), 1 )
          subClayWeights( n_hema, i ) = volumeIncrementsMineralsSubClay(
     &         mineralIndex( n_hema ) , i ) / volumeClaySiltMinerals(
     &         mineralIndex( n_hema ) , 1 )
          subClayWeights( n_aggr, i ) = (1 - frIronOxideInAggregate) *
     &         subClayWeights( n, i ) + frIronOxideInAggregate *
     &         subClayWeights( n_hema, i )

        end do

      end do

      do n = 1,ntm_dust

        zsum = sum( subClayWeights( n, : ) )
        if ( zsum == 0.d0 ) cycle
        subClayWeights( n, 1:nSubClays ) = subClayWeights( n,
     &       1:nSubClays ) / zsum
!        write(999,*) 'In TRDUST_DRV.f: In calcSubClayWeights: ',
!     &       'ntm_dust, n, dust_names(n),'
!     &       ,' subClayWeights( n, 1:nSubClays ): ', ntm_dust, n,
!     &       dust_names( n ), subClayWeights( n, 1:nSubClays )

      end do

      return
      end subroutine calcSubClayWeights

      end subroutine calcMineralRadiationParameters

c calcIronOxideAggregates
      subroutine calcIronOxideAggregates
!@sum calcIronOxideAggregates calculates aggregates of minerals with Iron
!@+     oxides from mineral fractions at emission
!@auth jan perlwitz

      implicit none

!@var ironOxideAggrProb probability of Iron oxide in aggregate with other
!@+     minerals
      real(kind=8), allocatable, dimension(:,:,:) :: ironOxideAggrProb
!@var sumIronOxideAggrProb sum over aggregate probabilities
      real(kind=8), allocatable, dimension(:,:,:) ::
     $     sumIronOxideAggrProb
!@var ironOxideFractions  fractions of Iron oxide for all the soil dust bins
!@+     used as temporary array
      real(kind=8), allocatable, dimension(:,:,:) :: ironOxideFractions

      integer :: i, j, m, n, n1, n_bin, n_hema, n_aggr, n2, n3
      real(kind=8) :: fac1, fac2, fac3, fac4, summinfr, y

c**** Treatment of Iron oxide minerals (Hematite+Goethite), other
c**** minerals, and internally mixed aggregates of Iron oxide with other
c**** minerals in grid box:
c**** 1. a) noAggregateByTotalFeox - prescribed initial mass fraction of
c****       Iron oxide minerals that remains unaggregated relative to
c****       all Iron oxide minerals (unaggregated plus aggregated with
c****       other minerals).
c****    b) noAggregateByTotalFeox - calculated as function of aggregation
c****       probability depending on mineral fractions in soil;
c****       probability of Iron oxide-other mineral aggegrate = (1 -
c****       fraction of Iron oxide) * fraction of other mineral.
c**** 2. frIronOxideInAggregate - prescribes the ratio of Iron oxide
c****    mass in internally mixed aggregate to total other mineral-Iron
c****    oxide aggregate mass.
c**** 3. unaggregated other mineral fraction equals initial other
c****    mineral fraction minus fraction of the available other mineral
c****    fraction that goes into aggregates. The other mineral fraction
c****    needed for aggregate formation increases with decreasing
c****    parameter frIronOxideInAggregate, decreasing the unaggregated
c****    other mineral fraction.
c**** 4. unaggregated Iron oxide fraction equals prescribed initial
c****    unaggregated Iron oxide fraction plus Iron oxide fraction that
c****    is not forming aggregates anymore, after the available other
c****    mineral fraction has been exhausted.
c**** 5. the fraction of internally mixed other mineral-Iron oxide
c****    aggregates depends on the fraction of Iron oxide that is
c****    allowed to form aggregates and the available other mineral
c****    fraction. It can't be larger than the initial other mineral
c****    fraction plus the available Iron oxide fraction mixed in
c****    according to parameter frIronOxideInAggregate.

      allocate( ironOxideAggrProb ( i_0h:i_1h, j_0h:j_1h, ntm_dust ) )
      allocate( ironOxideFractions( i_0h:i_1h, j_0h:j_1h, nDustBins ) )
      allocate( sumIronOxideAggrProb( i_0h:i_1h, j_0h:j_1h, nDustBins ))

!     calculate aggregation probabilities of minerals with Iron oxide in soil
      call calcIronOxideAggrProbSoil

      if ( frIronOxideInAggregate > 0.d0 ) then
        fac2 = 1.d0 / frIronOxideInAggregate
      else
        fac2 = 1.d0 / (frIronOxideInAggregate +
     $        tiny( frIronOxideInAggregate ))
      end if
      y = 1.d0 - frIronOxideInAggregate
      if ( y > 0.d0 ) then
        fac3 = 1.d0 / y
      else
        fac3 = 1.d0 / (y + tiny( y ))
      end if

      ironOxideFractions = 0.d0
      do n = 1,nDustBins

        select case( n )

        case( 1 )
          n1 = n_clayhema - n_soilDust + 1

        case( 2 )
          n1 = n_sil1hema - n_soilDust + 1

        case( 3 )
          n1 = n_sil2hema - n_soilDust + 1

        case( 4 )
          n1 = n_sil3hema - n_soilDust + 1

#ifdef TRACERS_DUST_Silt4
        case( 5 )
          n1 = n_sil4hema - n_soilDust + 1

#ifdef TRACERS_DUST_Silt5
        case( 6 )
          n1 = n_sil5hema - n_soilDust + 1
#endif
#endif

        case default
          cycle

        end select

        ironOxideFractions( :, :, n ) = mineralFractions( :, :, n1 )

C$$$        write( 999, * )
C$$$     $       'In TRDUST_DRV: In calcIronOxideAggregates: n, n1: ', n, n1
C$$$        ironOxideFractions( :, :, n ) = mineralFractions( :, :, n1 )
        where(  ironOxideFractions( :, :, n ) > 0.d0 )
          mineralFractions( :, :, n1 ) = (1.d0 - sumIronOxideAggrProb( :
     $          , :, n )) * ironOxideFractions( :, :, n )
        end where

C$$$        write( 999, * ) 'In TRDUST_DRV.f: In calcIronOxideAggregates: ',
C$$$     $       'mineralFractions( :, :, n1 ): ', mineralFractions( :, :,
C$$$     $       n1 )

      end do

c**** Calculation of unaggregated amount of mineral fraction by
c**** substracting the amount used for aggregates with Iron oxides

      do n = 1,ntm_dust

        select case( dust_names( n ) )

        case('ClayIlli','ClayKaol','ClaySmec','ClayCalc','ClayQuar'
     &         ,'ClayFeld','ClayGyps')
          n_hema = n_clayhema - n_soilDust + 1
          n_bin = 1
          select case ( dust_names( n ) )
          case('ClayIlli') ; n_aggr = n_clayilhe - n_soilDust + 1
          case('ClayKaol') ; n_aggr = n_claykahe - n_soilDust + 1
          case('ClaySmec') ; n_aggr = n_claysmhe - n_soilDust + 1
          case('ClayCalc') ; n_aggr = n_claycahe - n_soilDust + 1
          case('ClayQuar') ; n_aggr = n_clayquhe - n_soilDust + 1
          case('ClayFeld') ; n_aggr = n_clayfehe - n_soilDust + 1
          case('ClayGyps') ; n_aggr = n_claygyhe - n_soilDust + 1
          end select

        case('Sil1Quar','Sil1Feld','Sil1Calc','Sil1Gyps','Sil1Illi'
     &         ,'Sil1Kaol','Sil1Smec')
          n_hema = n_sil1hema - n_soilDust + 1
          n_bin = 2
          select case ( dust_names( n ) )
          case('Sil1Quar') ; n_aggr = n_sil1quhe - n_soilDust + 1
          case('Sil1Feld') ; n_aggr = n_sil1fehe - n_soilDust + 1
          case('Sil1Calc') ; n_aggr = n_sil1cahe - n_soilDust + 1
          case('Sil1Gyps') ; n_aggr = n_sil1gyhe - n_soilDust + 1
          case('Sil1Illi') ; n_aggr = n_sil1ilhe - n_soilDust + 1
          case('Sil1Kaol') ; n_aggr = n_sil1kahe - n_soilDust + 1
          case('Sil1Smec') ; n_aggr = n_sil1smhe - n_soilDust + 1
          end select

        case('Sil2Quar','Sil2Feld','Sil2Calc','Sil2Gyps','Sil2Illi'
     &         ,'Sil2Kaol','Sil2Smec')
          n_hema = n_sil2hema - n_soilDust + 1
          n_bin = 3
          select case ( dust_names( n ) )
          case('Sil2Quar') ; n_aggr = n_sil2quhe - n_soilDust + 1
          case('Sil2Feld') ; n_aggr = n_sil2fehe - n_soilDust + 1
          case('Sil2Calc') ; n_aggr = n_sil2cahe - n_soilDust + 1
          case('Sil2Gyps') ; n_aggr = n_sil2gyhe - n_soilDust + 1
          case('Sil2Illi') ; n_aggr = n_sil2ilhe - n_soilDust + 1
          case('Sil2Kaol') ; n_aggr = n_sil2kahe - n_soilDust + 1
          case('Sil2Smec') ; n_aggr = n_sil2smhe - n_soilDust + 1
          end select

        case('Sil3Quar','Sil3Feld','Sil3Calc','Sil3Gyps','Sil3Illi'
     &         ,'Sil3Kaol','Sil3Smec')
          n_hema = n_sil3hema - n_soilDust + 1
          n_bin = 4
          select case ( dust_names( n ) )
          case('Sil3Quar') ; n_aggr = n_sil3quhe - n_soilDust + 1
          case('Sil3Feld') ; n_aggr = n_sil3fehe - n_soilDust + 1
          case('Sil3Calc') ; n_aggr = n_sil3cahe - n_soilDust + 1
          case('Sil3Gyps') ; n_aggr = n_sil3gyhe - n_soilDust + 1
          case('Sil3Illi') ; n_aggr = n_sil3ilhe - n_soilDust + 1
          case('Sil3Kaol') ; n_aggr = n_sil3kahe - n_soilDust + 1
          case('Sil3Smec') ; n_aggr = n_sil3smhe - n_soilDust + 1
          end select

#ifdef TRACERS_DUST_Silt4
        case('Sil4Quar','Sil4Feld','Sil4Calc','Sil4Gyps','Sil4Illi'
     &         ,'Sil4Kaol','Sil4Smec')
          n_hema = n_sil4hema - n_soilDust + 1
          n_bin = 5
          select case ( dust_names( n ) )
          case('Sil4Quar') ; n_aggr = n_sil4quhe - n_soilDust + 1
          case('Sil4Feld') ; n_aggr = n_sil4fehe - n_soilDust + 1
          case('Sil4Calc') ; n_aggr = n_sil4cahe - n_soilDust + 1
          case('Sil4Gyps') ; n_aggr = n_sil4gyhe - n_soilDust + 1
          case('Sil4Illi') ; n_aggr = n_sil4ilhe - n_soilDust + 1
          case('Sil4Kaol') ; n_aggr = n_sil4kahe - n_soilDust + 1
          case('Sil4Smec') ; n_aggr = n_sil4smhe - n_soilDust + 1
          end select

#ifdef TRACERS_DUST_Silt5
        case('Sil5Quar','Sil5Feld','Sil5Calc','Sil5Gyps','Sil5Illi'
     &         ,'Sil5Kaol','Sil5Smec')
          n_hema = n_sil5hema - n_soilDust + 1
          n_bin = 6
          select case ( dust_names( n ) )
          case('Sil5Quar') ; n_aggr = n_sil5quhe - n_soilDust + 1
          case('Sil5Feld') ; n_aggr = n_sil5fehe - n_soilDust + 1
          case('Sil5Calc') ; n_aggr = n_sil5cahe - n_soilDust + 1
          case('Sil5Gyps') ; n_aggr = n_sil5gyhe - n_soilDust + 1
          case('Sil5Illi') ; n_aggr = n_sil5ilhe - n_soilDust + 1
          case('Sil5Kaol') ; n_aggr = n_sil5kahe - n_soilDust + 1
          case('Sil5Smec') ; n_aggr = n_sil5smhe - n_soilDust + 1
          end select

#endif
#endif
        case default
          cycle

        end select

!        write(999,*) 'In TRDUST_DRV.f: In calc calcIronOxideAggregates,'
!     &       , ' n, dust_names(n), n_bin, n_hema, dust_names(n_hema), '
!     &       , 'n_aggr, dust_names(n_aggr), fac2, fac3: ', n,
!     &       dust_names( n ), n_bin, n_hema, dust_names( n_hema ),
!     &       n_aggr, dust_names( n_aggr ), fac2, fac3

        do j = j_0,j_1
          do i = i_0,i_1

            fac1 = ironOxideAggrProb( i, j, n )
!            fac4 = fac1 * ironOxideFractions( i, j, n_bin ) * (fac2 -
!     &           1.d0)

!            if ( dust_names( n ) == 'Sil3Smec' ) call stop_model
!     &           ('In TRDUST_DRV: In calcIronOxideAggregates: ' //
!     &           'dust_names=Sil3Smec; Before mineralFractions(n)', 255
!     &           )

! calculate the fraction of mineral-Iron oxide aggregates from the Iron
! oxide fraction up to the exhaustion of available mineral
            mineralFractions( i, j, n_aggr ) = min( fac1 *
     &           ironOxideFractions( i, j, n_bin ) * fac2,
     &           mineralFractions( i, j, n ) * fac3 )

! calculate the non-aggregated Iron oxide fraction as sum of
! non-aggregated Iron oxide plus leftover Iron oxide after exhaustion of
! mineral available for aggregation with Iron oxide
!            mineralFractions( i, j, n_hema ) = mineralFractions( i, j,
!     &           n_hema ) + (1.d0 - fac1) * ironOxideFractions( i, j,
!     &           n_bin ) + max( fac1 * ironOxideFractions( i, j, n_bin )
!     &           - mineralFractions( i, j, n ) * fac3 / fac2, 0.d0 )

            mineralFractions( i, j, n_hema ) = mineralFractions( i, j,
     $           n_hema ) + max( fac1 * ironOxideFractions( i, j, n_bin)
     $           - frIronOxideInAggregate * mineralFractions( i , j,
     $           n_aggr ), 0.d0 )

! calculate the non-aggregated mineral fraction from initial mineral
! fraction minus the fraction used for mineral-Iron oxide aggregates up
! to the exhaustion of available mineral
!            mineralFractions( i, j, n ) = mineralFractions( i, j, n ) -
!     &           min( fac4, mineralFractions( i, j, n ) )
            mineralFractions( i, j, n ) = mineralFractions( i, j, n ) -
     $           y * mineralFractions( i, j, n_aggr )

          end do
        end do

        if ( any( mineralFractions( :, :, n ) < 0.d0 ) ) then
          write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: '
          write(999,*) '  i_0h, i_1h, j_0h, j_1h, n, dust_names(n), ',
     &         'mineralFraction: ',i_0h,i_1h, j_0h, j_1h, n,
     &         dust_names(n), mineralFractions( :, :, n )
          call stop_model( 'mineralFractions( :, :, n) < 0.d0', 255 )
        end if
        if ( any( mineralFractions( :, :, n_hema ) < 0.d0 ) ) then
          write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: '
          write(999,*) '  i_0h, i_1h, j_0h, j_1h, n_hema,  ',
     &         'dust_name(n_hema), mineralFraction: ',i_0h,i_1h, j_0h,
     &         j_1h, n_hema, dust_names(n_hema), mineralFractions( :, :,
     &         n_hema )
          call stop_model( 'mineralFractions( :, :, n_hema) < 0.d0',
     &         255)
        end if
        if ( any( mineralFractions( :, :, n_aggr ) < 0.d0 ) ) then
          write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: '
          write(999,*) '  i_0h, i_1h, j_0h, j_1h, n_aggr,  ',
     &         'dust_name(n_aggr), mineralFraction: ',i_0h,i_1h, j_0h,
     &         j_1h, n_aggr, dust_names(n_aggr), mineralFractions( :, :,
     &         n_aggr )
          call stop_model( 'mineralFractions( :, :, n_aggr) < 0.d0',
     &         255)
        end if

      end do

C$$$      write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: ',
C$$$     $     'sum( mineralFractions( :, :, clay ), dim=3 ): ', sum(
C$$$     $     mineralFractions( :, :, 1:ntm_clay ), dim=3 )

C$$$      n2 = ntm_clay
C$$$      n3 = n2 + ntm_sil1
C$$$      write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: ',
C$$$     $     'sum( mineralFractions( :, :, silt1 ), dim=3 ): ', sum(
C$$$     $     mineralFractions( :, :, n2+1:n3 ), dim=3 )

C$$$      n2 = n3
C$$$      n3 = n2 + ntm_sil2
C$$$      write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: ',
C$$$     $     'sum( mineralFractions( :, :, silt2 ), dim=3 ): ', sum(
C$$$     $     mineralFractions( :, :, n2+1:n3 ), dim=3 )

C$$$      n2 = n3
C$$$      n3 = n2 + ntm_sil3
C$$$      write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: ',
C$$$     $     'sum( mineralFractions( :, :, silt3 ), dim=3 ): ', sum(
C$$$     $     mineralFractions( :, :, n2+1:n3 ), dim=3 )

C$$$      n2 = n3
C$$$      n3 = n2 + ntm_sil4
C$$$      write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: ',
C$$$     $     'sum( mineralFractions( :, :, silt4 ), dim=3 ): ', sum(
C$$$     $     mineralFractions( :, :, n2+1:n3 ), dim=3 )

C$$$      n2 = ntm_clay
C$$$      n3 = n2 + ntm_sil1 + ntm_sil2 + ntm_sil3
C$$$      write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: ',
C$$$     &     'sum( mineralFractions( :, :, silt1tosilt3 ), dim=3 ): ',
C$$$     &     sum( mineralFractions( :, :, n2+1:n3 ), dim=3 )

C$$$      n2 = 0
C$$$      n3 = n2 + ntm_clay + ntm_sil1 + ntm_sil2 + ntm_sil3 + ntm_sil4
C$$$      write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggregates: ',
C$$$     &     'sum( mineralFractions( :, :, claytosilt4 ), dim=3 ): ',
C$$$     &     sum( mineralFractions( :, :, n2+1:n3 ), dim=3 )

      deallocate( ironOxideAggrProb, ironOxideFractions,
     $     sumIronOxideAggrProb )

      return

      contains

c calcIronOxideAggrProbSoil
      subroutine calcIronOxideAggrProbSoil
!@sum calcIronOxideAggrProbSoil  calculates aggregation probabilities of
!@+     Iron oxide with other minerals from mineral fractions in soil
!@auth jan perlwitz

      implicit none

      integer :: n, n_hema, n_bin

!@var fac1  temporary array for normalized Iron oxide mineralfraction
      real(kind=8), allocatable, dimension(:,:) :: fac1
!@var summinfr  sum over tracer fractions in a grid box and dust size bin
!@var summinfr2 sum over tracer fractions minus Iron oxide fraction
      real(kind=8), allocatable, dimension(:,:,:) :: summinfr, summinfr2
!@var mineralFractions_norm renormalized mineral fractions
!@+     (needed for calculation aggregation probabilities)    
      real(kind=8), allocatable, dimension(:,:,:) ::
     $     mineralFractions_norm

c**** Since the mineral fractions in soil do not add up to 1 after
c**** recalculating and re-weighting them in the procedures before, a
c**** re-normalization to 1 is necessary, using summinfr for calculating
c**** the aggregation probabilities.
      allocate( summinfr( i_0h:i_1h, j_0h:j_1h, nDustBins ) )
      allocate( summinfr2( i_0h:i_1h, j_0h:j_1h, nDustBins ) )
      allocate( mineralFractions_norm( i_0h:i_1h, j_0h:j_1h, ntm_dust ))
      allocate( fac1( i_0h:i_1h, j_0h:j_1h ) )

      ironOxideAggrProb = 0.d0
      summinfr = 0.d0
      summinfr2 = 0.d0
      mineralFractions_norm = 0.d0
      sumIronOxideAggrProb = 0.d0
      do n = 1,ntm_dust

        select case ( dust_names( n ) )

        case('ClayIlli','ClayKaol','ClaySmec','ClayCalc','ClayQuar'
     &         ,'ClayFeld','ClayHema','ClayGyps')
          n_bin = 1

        case('Sil1Quar','Sil1Feld','Sil1Calc','Sil1Hema','Sil1Gyps'
     &         ,'Sil1Illi','Sil1Kaol','Sil1Smec')
          n_bin = 2

        case('Sil2Quar','Sil2Feld','Sil2Calc','Sil2Hema','Sil2Gyps'
     &         ,'Sil2Illi','Sil2Kaol','Sil2Smec')
          n_bin = 3

        case('Sil3Quar','Sil3Feld','Sil3Calc','Sil3Hema','Sil3Gyps'
     &         ,'Sil3Illi','Sil3Kaol','Sil3Smec')
          n_bin = 4

#ifdef TRACERS_DUST_Silt4
        case('Sil4Quar','Sil4Feld','Sil4Calc','Sil4Hema','Sil4Gyps'
     &         ,'Sil4Illi','Sil4Kaol','Sil4Smec')
          n_bin = 5

#ifdef TRACERS_DUST_Silt5
        case('Sil5Quar','Sil5Feld','Sil5Calc','Sil5Hema','Sil5Gyps'
     &         ,'Sil5Illi','Sil5Kaol','Sil5Smec')
          n_bin = 6

#endif
#endif

        case default
          cycle

        end select

        summinfr( :, :, n_bin ) = summinfr( :, :, n_bin ) +
     &       mineralFractions( :, :, n )

      end do

      do n = 1,ntm_dust

        select case ( dust_names( n ) )

        case('ClayIlli','ClayKaol','ClaySmec','ClayCalc','ClayQuar'
     &         ,'ClayFeld','ClayHema','ClayGyps')
          n_bin = 1

        case('Sil1Quar','Sil1Feld','Sil1Calc','Sil1Hema','Sil1Gyps'
     &         ,'Sil1Illi','Sil1Kaol','Sil1Smec')
          n_bin = 2

        case('Sil2Quar','Sil2Feld','Sil2Calc','Sil2Hema','Sil2Gyps'
     &         ,'Sil2Illi','Sil2Kaol','Sil2Smec')
          n_bin = 3

        case('Sil3Quar','Sil3Feld','Sil3Calc','Sil3Hema','Sil3Gyps'
     &         ,'Sil3Illi','Sil3Kaol','Sil3Smec')
          n_bin = 4

#ifdef TRACERS_DUST_Silt4
        case('Sil4Quar','Sil4Feld','Sil4Calc','Sil4Hema','Sil4Gyps'
     &         ,'Sil4Illi','Sil4Kaol','Sil4Smec')
          n_bin = 5

#ifdef TRACERS_DUST_Silt5
        case('Sil5Quar','Sil5Feld','Sil5Calc','Sil5Hema','Sil5Gyps'
     &         ,'Sil5Illi','Sil5Kaol','Sil5Smec')
          n_bin = 6

#endif
#endif

        case default
          cycle

        end select

        where( summinfr( :, :, n_bin ) > 0.d0 )
          mineralFractions_norm( :, :, n ) = mineralFractions( :, :, n )
     $          / summinfr( :, :, n_bin )
        end where

        select case ( dust_names( n ) )

           case('ClayIlli','ClayKaol','ClaySmec','ClayCalc','ClayQuar'
     $          ,'ClayFeld','ClayGyps','Sil1Quar','Sil1Feld','Sil1Calc'
     $          ,'Sil1Gyps','Sil1Illi','Sil1Kaol','Sil1Smec','Sil2Quar'
     $          ,'Sil2Feld','Sil2Calc','Sil2Gyps','Sil2Illi','Sil2Kaol'
     $          ,'Sil2Smec','Sil3Quar','Sil3Feld','Sil3Calc','Sil3Gyps'
     $          ,'Sil3Illi','Sil3Kaol','Sil3Smec'
#ifdef TRACERS_DUST_Silt4
     &          ,'Sil4Quar','Sil4Feld','Sil4Calc','Sil4Gyps','Sil4Illi'
     $          ,'Sil4Kaol','Sil4Smec'
#ifdef TRACERS_DUST_Silt5
     &          ,'Sil5Quar','Sil5Feld','Sil5Calc','Sil5Gyps','Sil5Illi'
     $          ,'Sil5Kaol','Sil5Smec'
#endif
#endif
     &          )

           summinfr2( :, :, n_bin ) = summinfr2( :, :, n_bin ) +
     $          mineralFractions_norm( :, :, n )

        end select

      end do

C$$$      write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggrProbSoil: ',
C$$$     $     'sum( mineralFractions_norm( :, :, clay ), dim=3 ): ', sum(
C$$$     $     mineralFractions_norm( :, :, 1:ntm_clay ), dim=3 )

      do n = 1,ntm_dust

        select case ( dust_names( n ) )

        case('ClayIlli','ClayKaol','ClaySmec','ClayCalc','ClayQuar'
     &         ,'ClayFeld','ClayGyps')
          n_hema = n_clayhema - n_soilDust + 1
          n_bin = 1

        case('Sil1Quar','Sil1Feld','Sil1Calc','Sil1Gyps','Sil1Illi'
     &         ,'Sil1Kaol','Sil1Smec')
          n_hema = n_sil1hema - n_soilDust + 1
          n_bin = 2

        case('Sil2Quar','Sil2Feld','Sil2Calc','Sil2Gyps','Sil2Illi'
     &         ,'Sil2Kaol','Sil2Smec')
          n_hema = n_sil2hema - n_soilDust + 1
          n_bin = 3

        case('Sil3Quar','Sil3Feld','Sil3Calc','Sil3Gyps','Sil3Illi'
     &         ,'Sil3Kaol','Sil3Smec')
          n_hema = n_sil3hema - n_soilDust + 1
          n_bin = 4

#ifdef TRACERS_DUST_Silt4
        case('Sil4Quar','Sil4Feld','Sil4Calc','Sil4Gyps','Sil4Illi'
     &         ,'Sil4Kaol','Sil4Smec')
          n_hema = n_sil4hema - n_soilDust + 1
          n_bin = 5

#ifdef TRACERS_DUST_Silt5
        case('Sil5Quar','Sil5Feld','Sil5Calc','Sil5Gyps','Sil5Illi'
     &         ,'Sil5Kaol','Sil5Smec')
          n_hema = n_sil5hema - n_soilDust + 1
          n_bin = 6

#endif
#endif

        case default
          cycle

        end select

        if (  calcMineralAggrProb == 1 ) then
c          fac1( :, : ) = 1.d0 - mineralFractions_norm( :, :, n_hema ) /
c     &         (summinfr( :, :, n_bin ) + tiny( summinfr( :, :, n_bin
c     &         ) ) )
          where( mineralFractions_norm( :, :, n_hema ) > 0.d0 )
            fac1( :, : ) = 1.d0 - mineralFractions_norm( :, :, n_hema )
          else where
            fac1( :, : ) = 0.d0
          end where
        else
          fac1 = 1.d0 - noAggregateByTotalFeox
        end if

        where( summinfr2( :, :, n_bin ) > 0.d0 )
          ironOxideAggrProb( :, :, n ) = fac1( :, : ) *
     $          mineralFractions_norm( :, :, n ) / summinfr2( :, :,
     $          n_bin )
        end where

        sumIronOxideAggrProb( :, :, n_bin ) = sumIronOxideAggrProb( :, :
     $       , n_bin ) + ironOxideAggrProb( :, :, n )

!        write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggrProbSoil: ',
!     &       'n, dust_names(n), ','n_hema, dust_names(n_hema), nbin: ',
!     &       n, dust_names( n ), n_hema, dust_names(n_hema), n_bin
!        if ( dust_names( n ) == 'ClayIlli' ) then
!          write(999,*) 'In TRDUST_DRV.f: ',
!     &         'In calcIronOxideAggrProbSoil: '
!          write(999,*) '  i_0h, i_1h, j_0h, j_1h, summinfr: ', i_0h,
!     &         i_1h, j_0h, j_1h, summinfr( :,:, n_bin )
!          write(999,*) '  i_0h, i_1h, j_0h, j_1h, fac1: ', i_0h, i_1h,
!     &         j_0h,j_1h, fac1( :, : )
!          write(999,*) '  i_0h, i_1h, j_0h, j_1h, mineralFractions, ',
!     &         i_0h,i_1h, j_0h, j_1h, mineralFractions( :, :,n)
!          write(999,*) '  i_0h, i_1h, j_0h, j_1h, ironOxideAggrProb: ',
!     &         i_0h,i_1h, j_0h, j_1h, ironOxideAggrProb( :, :, n )
!        end if

      end do

C$$$      write(999,*) 'In TRDUST_DRV.f: In calcIronOxideAggrProbSoil: ',
C$$$     $     'sum( ironOxideAggrProb( :, :, clay ), dim=3 ): ', sum(
C$$$     $     ironOxideAggrProb( :, :, 1:ntm_clay ), dim=3 )

      do n = 1,ntm_dust

        select case ( dust_names( n ) )

        case('ClayIlli','ClayKaol','ClaySmec','ClayCalc','ClayQuar'
     &         ,'ClayFeld','ClayHema','ClayGyps')
          n_bin = 1

        case('Sil1Quar','Sil1Feld','Sil1Calc','Sil1Hema','Sil1Gyps'
     &         ,'Sil1Illi','Sil1Kaol','Sil1Smec')
          n_bin = 2

        case('Sil2Quar','Sil2Feld','Sil2Calc','Sil2Hema','Sil2Gyps'
     &         ,'Sil2Illi','Sil2Kaol','Sil2Smec')
          n_bin = 3

        case('Sil3Quar','Sil3Feld','Sil3Calc','Sil3Hema','Sil3Gyps'
     &         ,'Sil3Illi','Sil3Kaol','Sil3Smec')
          n_bin = 4

#ifdef TRACERS_DUST_Silt4
        case('Sil4Quar','Sil4Feld','Sil4Calc','Sil4Hema','Sil4Gyps'
     &         ,'Sil4Illi','Sil4Kaol','Sil4Smec')
          n_bin = 5

#ifdef TRACERS_DUST_Silt5
        case('Sil5Quar','Sil5Feld','Sil5Calc','Sil5Hema','Sil5Gyps'
     &         ,'Sil5Illi','Sil5Kaol','Sil5Smec')
          n_bin = 6

#endif
#endif

        end select

      end do

      do n = 1,1
         if ( any( sum(ironOxideAggrProb( :, :, (n-1)*ntm_clay+1:n
     $        *ntm_clay  ),dim=3) > 1.0d0) )then
         write(*,*) 'In TRDUST_DRV.f: In calcIronOxideAggrProbSoil: '
         write(*,*) '  i_0h, i_1h, j_0h, j_1h, bin, ',
     $        'sum(ironOxideAggrProb): ',i_0h,i_1h, j_0h, j_1h, n,
     $        sum(ironOxideAggrProb( :, :, (n-1)*ntm_clay+1:n *ntm_clay
     $        ),dim=3)
         call stop_model( 'sum(ironOxideAggrProb)( :, :, bin) > 1.01d0',
     $        255 )
        end if
      end do

      deallocate( fac1, summinfr, summinfr2, mineralFractions_norm )

      return
      end subroutine calcIronOxideAggrProbSoil

      end subroutine calcIronOxideAggregates

#endif /*  TRACERS_MINERALS */

c errorFunction
      real(kind=8) function errorFunction( z )
!@sum errorFunction  calculates error function using Taylor expansion
!@+     copied from http://en.wikipedia.org/wiki/Error_function
!@auth jan perlwitz

      real(kind=8), intent(in) :: z

      integer, parameter :: niter = 100

      integer :: k, n
      real(kind=8) :: pi, work, zadd, zk

      pi = 4.d0 * atan( 1.d0 )

      work = 0.d0
      do n = 0,niter-1
        zk = 1.d0
        do k = 1,n
          zk = zk * real( k, kind=8 )
        end do
        zadd = (-1.d0)**n * z * z**(2*n) / (2.d0*n+1.d0) / zk
!        write(999,*) 'In TRDUST_DRV.f: In errorFunction: n, zadd:', n,
!     &       zadd
        work = work + zadd
      end do

      errorFunction = 2.d0 * work / sqrt( pi )

!      write(999,*)
!     &     'In TRDUST_DRV.f: In errorFunction: z, errorFunction:',
!     &     z, 2.d0 * work / sqrt( pi )

      return
      end function errorFunction

c check_netcdf
      subroutine check_netcdf( status, infostring )
!@sum check_netcdf  checks for netcdf error messages
!@auth jan perlwitz

      use netcdf

      implicit none

      integer, intent(in) :: status
      character(len=*), intent(in) :: infostring

      character(len=256) :: outstring

      if( status /= nf90_noerr ) then
        outstring = trim( nf90_strerror( status ) ) // ' in ' // trim(
     &       infostring )
        call stop_model( trim( outstring ), 255 )
      end if

      return
      end subroutine check_netcdf

      end module trdust_drv
