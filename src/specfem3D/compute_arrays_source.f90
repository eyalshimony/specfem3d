!=====================================================================
!
!                          S p e c f e m 3 D
!                          -----------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                              CNRS, France
!                       and Princeton University, USA
!                 (there are currently many more authors!)
!                           (c) October 2017
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================


  subroutine compute_arrays_source_cmt(ispec_selected_source,sourcearray, &
                                       hxis,hetas,hgammas,hpxis,hpetas,hpgammas, &
                                       Mxx,Myy,Mzz,Mxy,Mxz,Myz)

  use constants
  use specfem_par, only: xixstore,xiystore,xizstore,etaxstore,etaystore,etazstore, &
                         gammaxstore,gammaystore,gammazstore,xix_regular,irregular_element_number

  implicit none

  integer, intent(in) :: ispec_selected_source

  real(kind=CUSTOM_REAL), dimension(NDIM,NGLLX,NGLLY,NGLLZ), intent(out) :: sourcearray

  double precision, dimension(NGLLX), intent(in) :: hxis,hpxis
  double precision, dimension(NGLLY), intent(in) :: hetas,hpetas
  double precision, dimension(NGLLZ), intent(in) :: hgammas,hpgammas
  double precision, intent(in) :: Mxx,Myy,Mzz,Mxy,Mxz,Myz

  ! local parameters
  double precision :: xixd,xiyd,xizd,etaxd,etayd,etazd,gammaxd,gammayd,gammazd

  ! source arrays
  double precision, dimension(NDIM,NGLLX,NGLLY,NGLLZ) :: sourcearrayd

  double precision :: hlagrange,hlagrange_xi,hlagrange_eta,hlagrange_gamma
  double precision :: dsrc_dx, dsrc_dy, dsrc_dz
  double precision :: dxis_dx, detas_dx, dgammas_dx
  double precision :: dxis_dy, detas_dy, dgammas_dy
  double precision :: dxis_dz, detas_dz, dgammas_dz
  double precision :: xix_reg_d

  integer :: k,l,m, ispec_irreg

  dxis_dx = ZERO
  dxis_dy = ZERO
  dxis_dz = ZERO
  detas_dx = ZERO
  detas_dy = ZERO
  detas_dz = ZERO
  dgammas_dx = ZERO
  dgammas_dy = ZERO
  dgammas_dz = ZERO

  ispec_irreg = irregular_element_number(ispec_selected_source)
  if (ispec_irreg == 0) xix_reg_d = dble(xix_regular)

  ! derivatives dxi/dx, dxi/dy, etc. evaluated at source position
  do m = 1,NGLLZ
    do l = 1,NGLLY
      do k = 1,NGLLX

        hlagrange = hxis(k) * hetas(l) * hgammas(m)

        if (ispec_irreg /= 0) then
          !irregular element
          xixd    = dble(xixstore(k,l,m,ispec_irreg))
          xiyd    = dble(xiystore(k,l,m,ispec_irreg))
          xizd    = dble(xizstore(k,l,m,ispec_irreg))
          etaxd   = dble(etaxstore(k,l,m,ispec_irreg))
          etayd   = dble(etaystore(k,l,m,ispec_irreg))
          etazd   = dble(etazstore(k,l,m,ispec_irreg))
          gammaxd = dble(gammaxstore(k,l,m,ispec_irreg))
          gammayd = dble(gammaystore(k,l,m,ispec_irreg))
          gammazd = dble(gammazstore(k,l,m,ispec_irreg))

          dxis_dx = dxis_dx + hlagrange * xixd
          dxis_dy = dxis_dy + hlagrange * xiyd
          dxis_dz = dxis_dz + hlagrange * xizd

          detas_dx = detas_dx + hlagrange * etaxd
          detas_dy = detas_dy + hlagrange * etayd
          detas_dz = detas_dz + hlagrange * etazd

          dgammas_dx = dgammas_dx + hlagrange * gammaxd
          dgammas_dy = dgammas_dy + hlagrange * gammayd
          dgammas_dz = dgammas_dz + hlagrange * gammazd
        else
          !regular element
          dxis_dx = dxis_dx + hlagrange * xix_reg_d
          detas_dy = detas_dy + hlagrange * xix_reg_d
          dgammas_dz = dgammas_dz + hlagrange * xix_reg_d
        endif
      enddo
    enddo
  enddo

  ! calculate source array
  sourcearrayd(:,:,:,:) = ZERO

  do m = 1,NGLLZ
    do l = 1,NGLLY
      do k = 1,NGLLX
        hlagrange_xi    = hpxis(k) *  hetas(l) *  hgammas(m)
        hlagrange_eta   =  hxis(k) * hpetas(l) *  hgammas(m)
        hlagrange_gamma =  hxis(k) *  hetas(l) * hpgammas(m)

        ! gradient at source position
        dsrc_dx = hlagrange_xi * dxis_dx &
                + hlagrange_eta * detas_dx &
                + hlagrange_gamma * dgammas_dx

        dsrc_dy = hlagrange_xi * dxis_dy &
                + hlagrange_eta * detas_dy &
                + hlagrange_gamma * dgammas_dy

        dsrc_dz = hlagrange_xi * dxis_dz &
                + hlagrange_eta * detas_dz &
                + hlagrange_gamma * dgammas_dz

        sourcearrayd(1,k,l,m) = sourcearrayd(1,k,l,m) + (Mxx*dsrc_dx + Mxy*dsrc_dy + Mxz*dsrc_dz)
        sourcearrayd(2,k,l,m) = sourcearrayd(2,k,l,m) + (Mxy*dsrc_dx + Myy*dsrc_dy + Myz*dsrc_dz)
        sourcearrayd(3,k,l,m) = sourcearrayd(3,k,l,m) + (Mxz*dsrc_dx + Myz*dsrc_dy + Mzz*dsrc_dz)
      enddo
    enddo
  enddo

  ! distinguish between single and double precision for reals
  sourcearray(:,:,:,:) = real(sourcearrayd(:,:,:,:), kind=CUSTOM_REAL)

  end subroutine compute_arrays_source_cmt

!
!-------------------------------------------------------------------------------------------------
!

! compute array for acoustic source

  subroutine compute_arrays_source_forcesolution(sourcearray,hxis,hetas,hgammas,factor_source,comp_x,comp_y,comp_z,nu_source)

  use constants

  implicit none

  real(kind=CUSTOM_REAL), dimension(NDIM,NGLLX,NGLLY,NGLLZ), intent(out) :: sourcearray

  double precision, dimension(NGLLX), intent(in) :: hxis
  double precision, dimension(NGLLY), intent(in) :: hetas
  double precision, dimension(NGLLZ), intent(in) :: hgammas
  double precision, intent(in) :: factor_source
  double precision, intent(in) :: comp_x,comp_y,comp_z
  double precision, dimension(NDIM,NDIM), intent(in) :: nu_source

  ! local parameters
  integer :: i,j,k
  double precision :: hlagrange
  double precision, dimension(NDIM,NGLLX,NGLLY,NGLLZ) :: sourcearrayd

  ! initializes
  sourcearrayd(:,:,:,:) = ZERO

  ! calculates source array for interpolated location
  do k = 1,NGLLZ
    do j = 1,NGLLY
      do i = 1,NGLLX
        hlagrange = hxis(i) * hetas(j) * hgammas(k)

        ! identical source array components in x,y,z-direction
        sourcearrayd(:,i,j,k) =  factor_source * hlagrange * ( nu_source(1,:) * comp_x + &
                                                               nu_source(2,:) * comp_y + &
                                                               nu_source(3,:) * comp_z )
      enddo
    enddo
  enddo

  ! distinguish between single and double precision for reals
  sourcearray(:,:,:,:) = real(sourcearrayd(:,:,:,:), kind=CUSTOM_REAL)

  end subroutine compute_arrays_source_forcesolution

!
!-------------------------------------------------------------------------------------------------
!

  subroutine compute_arrays_adjoint_source(adj_source_file,irec_local)

  use specfem_par, only: myrank,source_adjoint,NSTEP,NTSTEP_BETWEEN_READ_ADJSRC,it,READ_ADJSRC_ASDF

  use constants

  implicit none

  ! input
  integer, intent(in) :: irec_local
  character(len=*), intent(in) :: adj_source_file

  ! local
  integer :: icomp, itime, ier, it_start, it_end, it_sub_adj
  real(kind=CUSTOM_REAL), dimension(NTSTEP_BETWEEN_READ_ADJSRC) :: adj_source_asdf
  real(kind=CUSTOM_REAL) :: val,junk
  ! note: should have same order as orientation in write_seismograms_to_file()
  character(len=3),dimension(NDIM) :: comp
  character(len=MAX_STRING_LEN) :: filename

  ! gets channel names
  do icomp = 1,NDIM
    call write_channel_name(icomp,comp(icomp))
  enddo

  ! range of the block we need to read
  it_sub_adj = ceiling( dble(it)/dble(NTSTEP_BETWEEN_READ_ADJSRC) )
  it_start   = NSTEP - it_sub_adj*NTSTEP_BETWEEN_READ_ADJSRC + 1
  it_end     = it_start + NTSTEP_BETWEEN_READ_ADJSRC - 1

  if (READ_ADJSRC_ASDF) then
    ! ASDF format
    do icomp = 1,NDIM ! 3 components
      ! format: "net_sta_comp"
      filename = trim(adj_source_file) // '_' // comp(icomp)

      ! reads full trace (NSTEP)
      call read_adjoint_sources_ASDF(filename, adj_source_asdf, it_start, it_end)

      ! debug - check whether we read the correct block
      !if (icomp == 1) print *, junk, adj_source_asdf(itime-it_start+1,icomp)

      ! store the block we need
      do itime = it_start, it_end
        ! store adjoint trace
        source_adjoint(icomp,irec_local,itime-it_start+1) = adj_source_asdf(itime-it_start+1)
      enddo
    enddo

  else
    ! ASCII format
    ! loops over components
    do icomp = 1, NDIM
      ! format: "SEM/net.sta.comp.adj"
      filename = OUTPUT_FILES(1:len_trim(OUTPUT_FILES))//'/../SEM/'//trim(adj_source_file)//'.'//comp(icomp)//'.adj'

      open(unit=IIN,file=trim(filename),status='old',action='read',iostat = ier)
      ! cycles to next file (this might be more error prone)
      !if (ier /= 0) cycle
      ! requires adjoint files to exist (users will have to be more careful in setting up adjoint runs)
      if (ier /= 0) call exit_MPI(myrank, ' file '//trim(filename)//' does not exist - required for adjoint runs')

      ! reads in adjoint source trace
      !! skip unused blocks
      do itime = 1, it_start-1
        read(IIN,*,iostat=ier) junk, junk
        if (ier /= 0) then
          call exit_MPI(myrank,'file '//trim(filename)//' has wrong length, please check with your simulation duration (1)')
        endif
      enddo

      !! read the block we need
      do itime = it_start, it_end
        read(IIN,*,iostat=ier) junk, val
        if (ier /= 0) then
          call exit_MPI(myrank,'file '//trim(filename)//' has wrong length, please check with your simulation duration (2)')
        endif

        ! store adjoint trace
        source_adjoint(icomp,irec_local,itime-it_start+1) = val
      enddo

      close(IIN)

    enddo
  endif

  end subroutine compute_arrays_adjoint_source

!
!-------------------------------------------------------------------------------------------------
!

  subroutine compute_arrays_adjoint_source_SU(idomain)

  use specfem_par, only: myrank,source_adjoint,it,NSTEP,NTSTEP_BETWEEN_READ_ADJSRC,nrec_local
  use constants

  implicit none
  integer, intent(in) :: idomain
  ! local parameters
  real(kind=CUSTOM_REAL), dimension(NTSTEP_BETWEEN_READ_ADJSRC) :: adj_temp
  integer :: ier, irec_local, it_start, it_sub_adj
  logical :: found_adjoint_files

  ! note: should have same order as orientation in write_seismograms_to_file()
  character(len=MAX_STRING_LEN) :: procname, filename_p, filename_x, filename_y, filename_z

  ! check if anything to read for this slice
  if (nrec_local < 1) return

  ! range of the block we need to read
  it_sub_adj = ceiling( dble(it)/dble(NTSTEP_BETWEEN_READ_ADJSRC) )
  it_start = NSTEP - it_sub_adj*NTSTEP_BETWEEN_READ_ADJSRC

  write(procname,"(i4)") myrank

  ! check if we have adjoint traces
  found_adjoint_files = .false.

  select case(idomain)
  case (IDOMAIN_ACOUSTIC)
    ! get acoustic adjoint traces
    ! SU adjoint file name
    filename_p = trim(OUTPUT_FILES)//'../SEM/'//trim(adjustl(procname))//'_p_SU.adj'

    ! check if file exists
    inquire(file=trim(filename_p),exist=found_adjoint_files)

    ! read file
    if (found_adjoint_files) then
      ! user output
      if (myrank == 0) then
        write(IMAIN,*) 'reading acoustic adjoint traces:'
        write(IMAIN,*) '  ',trim(filename_p)
        write(IMAIN,*) '  using SU_FORMAT'
        write(IMAIN,*)
        write(IMAIN,*) '  start index  = ',it_start
        write(IMAIN,*) '  trace length = ',NTSTEP_BETWEEN_READ_ADJSRC
        write(IMAIN,*)
        call flush_IMAIN()
      endif

      open(unit=IIN_SU1,file=trim(filename_p),status='old',access='stream',iostat = ier)
      if (ier /= 0) call exit_MPI(myrank,'file '//trim(filename_p)//' does not exist')
      do irec_local = 1,nrec_local
         read(IIN_SU1,pos=4*((irec_local-1)*(60+NSTEP) + 60 + it_start)+1 ) adj_temp
         source_adjoint(1,irec_local,:) = adj_temp(:)
         source_adjoint(2,irec_local,:) = 0.0_CUSTOM_REAL  !TRIVIAL
         source_adjoint(3,irec_local,:) = 0.0_CUSTOM_REAL  !TRIVIAL
      enddo
      close(IIN_SU1)
    endif

  case (IDOMAIN_ELASTIC)
    ! get elastic adjoint traces
    ! SU adjoint file names
    ! x-direction traces
    filename_x = trim(OUTPUT_FILES)//'../SEM/'//trim(adjustl(procname))//'_dx_SU.adj'
    ! y-direction traces
    filename_y = trim(OUTPUT_FILES)//'../SEM/'//trim(adjustl(procname))//'_dy_SU.adj'
    ! z-direction traces
    filename_z = trim(OUTPUT_FILES)//'../SEM/'//trim(adjustl(procname))//'_dz_SU.adj'

    ! check if x-file exists
    inquire(file=trim(filename_x),exist=found_adjoint_files)
    if (found_adjoint_files) then
      ! check if y-file exists
      inquire(file=trim(filename_y),exist=found_adjoint_files)
      if (found_adjoint_files) then
        ! check if z-file exists
        inquire(file=trim(filename_z),exist=found_adjoint_files)
      endif
    endif

    if (found_adjoint_files) then
      ! user output
      if (myrank == 0) then
        write(IMAIN,*) 'reading elastic adjoint traces:'
        write(IMAIN,*) '  ',trim(filename_x)
        write(IMAIN,*) '  ',trim(filename_y)
        write(IMAIN,*) '  ',trim(filename_z)
        write(IMAIN,*) '  using SU_FORMAT'
        write(IMAIN,*)
        write(IMAIN,*) '  start index  = ',it_start
        write(IMAIN,*) '  trace length = ',NTSTEP_BETWEEN_READ_ADJSRC
        write(IMAIN,*)
        call flush_IMAIN()
      endif

      ! opens files
      open(unit=IIN_SU1,file=trim(filename_x),status='old',access='stream',iostat = ier)
      if (ier /= 0) call exit_MPI(myrank,'file '//trim(filename_x)//' does not exist')

      open(unit=IIN_SU2,file=trim(filename_y),status='old',access='stream',iostat = ier)
      if (ier /= 0) call exit_MPI(myrank,'file '//trim(filename_y)//' does not exist')

      open(unit=IIN_SU3,file=trim(filename_z),status='old',access='stream',iostat = ier)
      if (ier /= 0) call exit_MPI(myrank,'file '//trim(filename_z)//' does not exist')

      ! reads traces
      do irec_local = 1,nrec_local
         read(IIN_SU1,pos=4*((irec_local-1)*(60+NSTEP) + 60 + it_start)+1 ) adj_temp
         source_adjoint(1,irec_local,:) = adj_temp(:)

         read(IIN_SU2,pos=4*((irec_local-1)*(60+NSTEP) + 60 + it_start)+1 ) adj_temp
         source_adjoint(2,irec_local,:) = adj_temp(:)

         read(IIN_SU3,pos=4*((irec_local-1)*(60+NSTEP) + 60 + it_start)+1 ) adj_temp
         source_adjoint(3,irec_local,:) = adj_temp(:)
      enddo

      close(IIN_SU1)
      close(IIN_SU2)
      close(IIN_SU3)
    endif

  case (IDOMAIN_POROELASTIC)
    ! not implemented yet
    call exit_MPI(myrank,'SU_FORMAT not implemented for adjoint sources in poroelastic domains yet')

  case default
    ! domain not recognized
    call exit_MPI(myrank,'Invalid domain for SU_FORMAT adjoint sources')

  end select

  ! debug - check if file found
  !if (.not. found_adjoint_files) then
  !  call exit_MPI(myrank,'Found no adjoint traces in SU_FORMAT')
  !endif

  end subroutine compute_arrays_adjoint_source_SU

!
!-------------------------------------------------------------------------------------------------
!


  subroutine compute_arrays_source_forcesolution_fluid(ispec_selected_source,sourcearray, &
                                                       hxis,hetas,hgammas,hpxis,hpetas,hpgammas, &
                                                       factor_source, comp_x,comp_y,comp_z, nu_source)
  use constants

  use specfem_par, only: xixstore,xiystore,xizstore,etaxstore,etaystore,etazstore, &
                         gammaxstore,gammaystore,gammazstore, &
                         irregular_element_number,xix_regular

  implicit none

  integer, intent(in) :: ispec_selected_source

  real(kind=CUSTOM_REAL), dimension(NDIM,NGLLX,NGLLY,NGLLZ), intent(out) :: sourcearray

  double precision, dimension(NGLLX), intent(in) :: hxis,hpxis
  double precision, dimension(NGLLY), intent(in) :: hetas,hpetas
  double precision, dimension(NGLLZ), intent(in) :: hgammas,hpgammas
  double precision, dimension(NDIM,NDIM), intent(in) :: nu_source
  double precision, intent(in) :: comp_x,comp_y,comp_z
  double precision, intent(in) :: factor_source

  double precision :: FX, FY, FZ

  ! local parameters
  integer :: ispec_irreg
  double precision :: xixd,xiyd,xizd,etaxd,etayd,etazd,gammaxd,gammayd,gammazd

  ! source arrays
  double precision, dimension(NDIM,NGLLX,NGLLY,NGLLZ) :: sourcearrayd

  double precision :: hlagrange,hlagrange_xi,hlagrange_eta,hlagrange_gamma
  double precision :: dsrc_dx, dsrc_dy, dsrc_dz
  double precision :: dxis_dx, detas_dx, dgammas_dx
  double precision :: dxis_dy, detas_dy, dgammas_dy
  double precision :: dxis_dz, detas_dz, dgammas_dz

  integer :: k,l,m

  dxis_dx = ZERO
  dxis_dy = ZERO
  dxis_dz = ZERO
  detas_dx = ZERO
  detas_dy = ZERO
  detas_dz = ZERO
  dgammas_dx = ZERO
  dgammas_dy = ZERO
  dgammas_dz = ZERO

  ispec_irreg = irregular_element_number(ispec_selected_source)
  if (ispec_irreg == 0) xixd = dble(xix_regular)

  do m = 1,NGLLZ
    do l = 1,NGLLY
      do k = 1,NGLLX

        hlagrange = hxis(k) * hetas(l) * hgammas(m)

        if (ispec_irreg /= 0) then
          !irregular element
          xixd    = dble(xixstore(k,l,m,ispec_irreg))
          xiyd    = dble(xiystore(k,l,m,ispec_irreg))
          xizd    = dble(xizstore(k,l,m,ispec_irreg))
          etaxd   = dble(etaxstore(k,l,m,ispec_irreg))
          etayd   = dble(etaystore(k,l,m,ispec_irreg))
          etazd   = dble(etazstore(k,l,m,ispec_irreg))
          gammaxd = dble(gammaxstore(k,l,m,ispec_irreg))
          gammayd = dble(gammaystore(k,l,m,ispec_irreg))
          gammazd = dble(gammazstore(k,l,m,ispec_irreg))

          dxis_dx = dxis_dx + hlagrange * xixd
          dxis_dy = dxis_dy + hlagrange * xiyd
          dxis_dz = dxis_dz + hlagrange * xizd

          detas_dx = detas_dx + hlagrange * etaxd
          detas_dy = detas_dy + hlagrange * etayd
          detas_dz = detas_dz + hlagrange * etazd

          dgammas_dx = dgammas_dx + hlagrange * gammaxd
          dgammas_dy = dgammas_dy + hlagrange * gammayd
          dgammas_dz = dgammas_dz + hlagrange * gammazd

        else
          ! regular_element
          dxis_dx = dxis_dx + hlagrange * xixd
          detas_dy = detas_dy + hlagrange * xixd
          dgammas_dz = dgammas_dz + hlagrange * xixd
        endif

      enddo
    enddo
  enddo

  FX = factor_source * (nu_source(1,1)*comp_x + nu_source(1,2)*comp_y +  nu_source(1,3)*comp_z)
  FY = factor_source * (nu_source(2,1)*comp_x + nu_source(2,2)*comp_y +  nu_source(2,3)*comp_z)
  FZ = factor_source * (nu_source(3,1)*comp_x + nu_source(3,2)*comp_y +  nu_source(3,3)*comp_z)

  ! calculate source array
  sourcearrayd(:,:,:,:) = ZERO

  do m = 1,NGLLZ
    do l = 1,NGLLY
      do k = 1,NGLLX
        hlagrange_xi = hpxis(k)*hetas(l)*hgammas(m)
        hlagrange_eta = hxis(k)*hpetas(l)*hgammas(m)
        hlagrange_gamma = hxis(k)*hetas(l)*hpgammas(m)

        dsrc_dx = hlagrange_xi * dxis_dx &
                + hlagrange_eta * detas_dx &
                + hlagrange_gamma * dgammas_dx

        dsrc_dy = hlagrange_xi * dxis_dy &
                + hlagrange_eta * detas_dy &
                + hlagrange_gamma * dgammas_dy

        dsrc_dz = hlagrange_xi * dxis_dz &
                + hlagrange_eta * detas_dz &
                + hlagrange_gamma * dgammas_dz

        !! for now fixed force direction and stf is defined after
        sourcearrayd(:,k,l,m) = sourcearrayd(:,k,l,m) + (FX*dsrc_dx + FY*dsrc_dy + FZ*dsrc_dz)

        !! to do :
        !!  this is for time changing force direction
        !! sourcearrayd(1,k,l,m) = sourcearrayd(1,k,l,m) +  dsrc_dx  * (stf_comp_x(t))
        !! sourcearrayd(2,k,l,m) = sourcearrayd(2,k,l,m) +  dsrc_dy  * (stf_comp_y(t))
        !! sourcearrayd(3,k,l,m) = sourcearrayd(3,k,l,m) +  dsrc_dz  * (stf_comp_z(t))
        !!
        !! after we need to add : sum(sourcearrayd(:,k,l,m)) to acoustic potential
        !! or sourcearrayd(1,k,l,m) * stf_comp_x(t) +
        !!    sourcearrayd(2,k,l,m) * stf_comp_y(t) +
        !!    sourcearrayd(3,k,l,m) * stf_comp_z(t)
        !!

      enddo
    enddo
  enddo

  ! distinguish between single and double precision for reals
  sourcearray(:,:,:,:) = real(sourcearrayd(:,:,:,:), kind=CUSTOM_REAL)

  end subroutine compute_arrays_source_forcesolution_fluid
