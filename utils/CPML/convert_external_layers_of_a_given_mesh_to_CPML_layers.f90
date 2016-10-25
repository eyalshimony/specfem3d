!=====================================================================
!
!               S p e c f e m 3 D  V e r s i o n  3 . 0
!               ---------------------------------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!                and CNRS / University of Marseille, France
!                 (there are currently many more authors!)
! (c) Princeton University and CNRS / University of Marseille, July 2012
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 2 of the License, or
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

  program convert_mesh_to_CPML

! Dimitri Komatitsch, CNRS Marseille, France, April 2013

! convert outer layers of an existing CUBIT mesh file stored in SPECFEM3D_Cartesian format to CPML layers,
! i.e., create a 'absorbing_cpml_file' file for that existing mesh

  implicit none

! this is for HEX8; the code below also works for HEX27, it then just uses the first 8 points of an element
! to determine if it belongs to a CPML layer
  integer, parameter :: NGNOD = 8

  integer :: nspec,npoin
  integer :: ispec,ipoin
  integer :: ipoin_read,ispec_loop,iflag,iformat,iread
  integer :: i1,i2,i3,i4,i5,i6,i7,i8,number_of_CPML_elements,count_faces_found

  double precision, dimension(:), allocatable :: x,y,z

  logical, dimension(:), allocatable :: is_X_CPML,is_Y_CPML,is_Z_CPML

  double precision :: xread,yread,zread,xmin,xmax,ymin,ymax,zmin,zmax,limit,size_of_model

  logical :: ALSO_ADD_ON_THE_TOP_SURFACE,already_found_a_face

  double precision :: THICKNESS_OF_XMIN_PML,THICKNESS_OF_YMIN_PML,THICKNESS_OF_ZMIN_PML
  double precision :: THICKNESS_OF_XMAX_PML,THICKNESS_OF_YMAX_PML,THICKNESS_OF_ZMAX_PML

  integer, dimension(:,:), allocatable :: ibool

! to make sure coordinate roundoff problems do not occur, use a tolerance of 0.5%
  double precision, parameter :: SMALL_PERCENTAGE_TOLERANCE = 1.005d0

  double precision, parameter :: SMALL_RELATIVE_VALUE = 0.5d-3

! flags for the seven CPML regions
  integer, parameter :: CPML_X_ONLY = 1
  integer, parameter :: CPML_Y_ONLY = 2
  integer, parameter :: CPML_Z_ONLY = 3
  integer, parameter :: CPML_XY_ONLY = 4
  integer, parameter :: CPML_XZ_ONLY = 5
  integer, parameter :: CPML_YZ_ONLY = 6
  integer, parameter :: CPML_XYZ = 7

  print *
  print *,'IMPORTANT: it is your responsibility to make sure that in the input CUBIT (or similar) mesh'
  print *,'that this code will read in SPECFEM3D format from files "nodes_coords_file" and "mesh_file"'
  print *,'you have created layers of elements that constitute a layer of constant thickness aligned'
  print *,'with the coordinate grid axes (X, Y and/or Z), so that this code can assign CPML flags to them.'
  print *,'This code does NOT check that (because it cannot, in any easy way).'
  print *,'The mesh inside these CPML layers does not need to be structured nor regular, any non-structured'
  print *,'mesh is fine as long as it has flat PML inner and outer faces, parallel to the axes, and thus'
  print *,'of a constant thickness.'
  print *,'The thickness can be different between the X, Y and Z sides. But for X it must not vary,'
  print *,'for Y it must not vary, and for Z it must not vary.'
  print *,'If you do not know the exact thickness, you can use a slightly LARGER value'
  print *,'in this code (say 2% to 5% more) and this code will fix that and will adjust it;'
  print *,'never use a SMALLER value otherwise this code will miss some CPML elements.'
  print *
  print *,'Note: in a future release we will remove the constraint of having CPML layers aligned with the'
  print *,'coordinate axes; we will allow for meshes that are titled by any constant angle in the horizontal plane.'
  print *,'However this is not implemented yet.'
  print *

  print *,'1 = read the mesh files in ASCII format (that is the standard case)'
  print *,'2 = read the mesh files in binary format (that is much faster, if your mesh is available in that format)'
  print *,'  (if not, you can run xconvert_mesh_files_from_ASCII_to_binary)'
  print *,'3 = exit'
  read(*,*) iformat
  if (iformat /= 1 .and. iformat /= 2) stop 'exiting...'

  print *
  print *,'1 = use a free surface at the top of the mesh (most classical option)'
  print *,'2 = use a CPML absorbing layer at the top of the mesh (less classical option)'
  print *,'3 = exit'
  read(*,*) iflag
  if (iflag /= 1 .and. iflag /= 2) stop 'exiting...'
  if (iflag == 1) then
    ALSO_ADD_ON_THE_TOP_SURFACE = .false.
  else
    ALSO_ADD_ON_THE_TOP_SURFACE = .true.
  endif
  print *

  print *,'1 = enter the CPML thickness values to create manually'
  print *,'2 = read them from a file created by the previous code, xconvert_external_layers_of_a_given_mesh_to_CPML_layers'
  print *,'3 = exit'
  read(*,*) iread
  if (iread /= 1 .and. iread /= 2) stop 'exiting...'

! open SPECFEM3D_Cartesian mesh file to read the points
  if (iformat == 1) then
    open(unit=23,file='nodes_coords_file',status='old',action='read')
    read(23,*) npoin
  else
    open(unit=23,file='nodes_coords_file.bin',form='unformatted',status='old',action='read')
    read(23) npoin
  endif
  allocate(x(npoin))
  allocate(y(npoin))
  allocate(z(npoin))
  if (iformat == 1) then
    do ipoin = 1,npoin
      read(23,*) ipoin_read,xread,yread,zread
      x(ipoin_read) = xread
      y(ipoin_read) = yread
      z(ipoin_read) = zread
    enddo
  else
    read(23) x
    read(23) y
    read(23) z
  endif
  close(23)

! compute the min and max values of each coordinate
   xmin = minval(x)
   xmax = maxval(x)

   ymin = minval(y)
   ymax = maxval(y)

   zmin = minval(z)
   zmax = maxval(z)

  print *,'Xmin and Xmax of the mesh read = ',xmin,xmax
  print *,'Ymin and Ymax of the mesh read = ',ymin,ymax
  print *,'Zmin and Zmax of the mesh read = ',zmin,zmax
  print *

  if (iread == 2) then

! read the thickness values from an existing text file
  open(unit=23,file='values_to_use_for_convert_external_layers_of_a_given_mesh_to_CPML_layers.txt',status='old',action='read')
  read(23,*) THICKNESS_OF_XMIN_PML
  read(23,*) THICKNESS_OF_XMAX_PML
  read(23,*) THICKNESS_OF_YMIN_PML
  read(23,*) THICKNESS_OF_YMAX_PML
  read(23,*) THICKNESS_OF_ZMIN_PML
  read(23,*) THICKNESS_OF_ZMAX_PML
  close(23)
! check convention (negative value) that says that this Zmax absorbing edge is turned off
  if (ALSO_ADD_ON_THE_TOP_SURFACE .and. THICKNESS_OF_ZMAX_PML <= 0) &
    stop 'negative thickness is not allowed; ALSO_ADD_ON_THE_TOP_SURFACE is maybe inconsistent with the previous code; exiting...'
  if (.not. ALSO_ADD_ON_THE_TOP_SURFACE .and. THICKNESS_OF_ZMAX_PML > 0) &
    stop 'ALSO_ADD_ON_THE_TOP_SURFACE seems inconsistent with the previous code; exiting...'

  else

  print *,'What is the exact thickness of the PML layer that you want'
  print *,'on the Xmin face of your mesh? (it needs to correspond exactly'
  print *,'to the flat layers you created in your input CUBIT mesh, as mentioned in'
  print *,'the comment printed above; if you think you have roundoff issues or very'
  print *,'slightly varying thickness, give 2% or 5% more here, but never less'
  read(*,*) THICKNESS_OF_XMIN_PML
  if (THICKNESS_OF_XMIN_PML <= 0) stop 'negative thickness is not allowed; exiting...'
  if (THICKNESS_OF_XMIN_PML > 0.30*(xmax - xmin)) &
    stop 'thickness of each CPML layer greater than 30% of the size of the mesh is not a good idea; exiting...'
  print *

  print *,'What is the exact thickness of the PML layer that you want'
  print *,'on the Xmax face of your mesh?'
  read(*,*) THICKNESS_OF_XMAX_PML
  if (THICKNESS_OF_XMAX_PML <= 0) stop 'negative thickness is not allowed; exiting...'
  if (THICKNESS_OF_XMAX_PML > 0.30*(xmax - xmin)) &
    stop 'thickness of each CPML layer greater than 30% of the size of the mesh is not a good idea; exiting...'
  print *

  print *,'What is the exact thickness of the PML layer that you want'
  print *,'on the Ymin face of your mesh?'
  read(*,*) THICKNESS_OF_YMIN_PML
  if (THICKNESS_OF_YMIN_PML <= 0) stop 'negative thickness is not allowed; exiting...'
  if (THICKNESS_OF_YMIN_PML > 0.30*(ymax - ymin)) &
    stop 'thickness of each CPML layer greater than 30% of the size of the mesh is not a good idea; exiting...'
  print *

  print *,'What is the exact thickness of the PML layer that you want'
  print *,'on the Ymax face of your mesh?'
  read(*,*) THICKNESS_OF_YMAX_PML
  if (THICKNESS_OF_YMAX_PML <= 0) stop 'negative thickness is not allowed; exiting...'
  if (THICKNESS_OF_YMAX_PML > 0.30*(ymax - ymin)) &
    stop 'thickness of each CPML layer greater than 30% of the size of the mesh is not a good idea; exiting...'
  print *

  print *,'What is the exact thickness of the PML layer that you want'
  print *,'on the Zmin face of your mesh?'
  read(*,*) THICKNESS_OF_ZMIN_PML
  if (THICKNESS_OF_ZMIN_PML <= 0) stop 'negative thickness is not allowed; exiting...'
  if (THICKNESS_OF_ZMIN_PML > 0.30*(zmax - zmin)) &
    stop 'thickness of each CPML layer greater than 30% of the size of the mesh is not a good idea; exiting...'
  print *

  if (ALSO_ADD_ON_THE_TOP_SURFACE) then
    print *,'What is the exact thickness of the PML layer that you want'
    print *,'on the Zmax face of your mesh?'
    read(*,*) THICKNESS_OF_ZMAX_PML
    if (THICKNESS_OF_ZMAX_PML <= 0) stop 'negative thickness is not allowed; exiting...'
    if (THICKNESS_OF_ZMAX_PML > 0.30*(zmax - zmin)) &
      stop 'thickness of each CPML layer greater than 30% of the size of the mesh is not a good idea; exiting...'
    print *
  endif

  endif

! ************* read mesh elements and generate CPML flags *************

! open SPECFEM3D_Cartesian topology file to read the mesh elements
  if (iformat == 1) then
    open(unit=23,file='mesh_file',status='old',action='read')
    read(23,*) nspec
  else
    open(unit=23,file='mesh_file.bin',form='unformatted',status='old',action='read')
    read(23) nspec
  endif

  allocate(is_X_CPML(nspec))
  allocate(is_Y_CPML(nspec))
  allocate(is_Z_CPML(nspec))

  is_X_CPML(:) = .false.
  is_Y_CPML(:) = .false.
  is_Z_CPML(:) = .false.

  allocate(ibool(NGNOD,nspec))

! loop on the whole mesh
  if (iformat == 1) then
    do ispec_loop = 1,nspec
      read(23,*) ispec,i1,i2,i3,i4,i5,i6,i7,i8
! store the ibool() array read
      ibool(1,ispec) = i1
      ibool(2,ispec) = i2
      ibool(3,ispec) = i3
      ibool(4,ispec) = i4
      ibool(5,ispec) = i5
      ibool(6,ispec) = i6
      ibool(7,ispec) = i7
      ibool(8,ispec) = i8
    enddo
  else
    read(23) ibool
  endif

  close(23)

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

! Xmin CPML
    limit = xmin + THICKNESS_OF_XMIN_PML * SMALL_PERCENTAGE_TOLERANCE
    if (x(i1) < limit .and. x(i2) < limit .and. x(i3) < limit .and. x(i4) < limit .and. &
       x(i5) < limit .and. x(i6) < limit .and. x(i7) < limit .and. x(i8) < limit) is_X_CPML(ispec) = .true.

! Xmax CPML
    limit = xmax - THICKNESS_OF_XMAX_PML * SMALL_PERCENTAGE_TOLERANCE
    if (x(i1) > limit .and. x(i2) > limit .and. x(i3) > limit .and. x(i4) > limit .and. &
       x(i5) > limit .and. x(i6) > limit .and. x(i7) > limit .and. x(i8) > limit) is_X_CPML(ispec) = .true.

! Ymin CPML
    limit = ymin + THICKNESS_OF_YMIN_PML * SMALL_PERCENTAGE_TOLERANCE
    if (y(i1) < limit .and. y(i2) < limit .and. y(i3) < limit .and. y(i4) < limit .and. &
       y(i5) < limit .and. y(i6) < limit .and. y(i7) < limit .and. y(i8) < limit) is_Y_CPML(ispec) = .true.

! Ymax CPML
    limit = ymax - THICKNESS_OF_YMAX_PML * SMALL_PERCENTAGE_TOLERANCE
    if (y(i1) > limit .and. y(i2) > limit .and. y(i3) > limit .and. y(i4) > limit .and. &
       y(i5) > limit .and. y(i6) > limit .and. y(i7) > limit .and. y(i8) > limit) is_Y_CPML(ispec) = .true.

! Zmin CPML
    limit = zmin + THICKNESS_OF_ZMIN_PML * SMALL_PERCENTAGE_TOLERANCE
    if (z(i1) < limit .and. z(i2) < limit .and. z(i3) < limit .and. z(i4) < limit .and. &
       z(i5) < limit .and. z(i6) < limit .and. z(i7) < limit .and. z(i8) < limit) is_Z_CPML(ispec) = .true.

! Zmax CPML
  if (ALSO_ADD_ON_THE_TOP_SURFACE) then
    limit = zmax - THICKNESS_OF_ZMAX_PML * SMALL_PERCENTAGE_TOLERANCE
    if (z(i1) > limit .and. z(i2) > limit .and. z(i3) > limit .and. z(i4) > limit .and. &
       z(i5) > limit .and. z(i6) > limit .and. z(i7) > limit .and. z(i8) > limit) is_Z_CPML(ispec) = .true.
  endif

  enddo

  print *,'Total number of elements in the mesh read = ',nspec
  print *
  print *,'Found ',count(is_X_CPML),' X_CPML elements'
  print *,'Found ',count(is_Y_CPML),' Y_CPML elements'
  print *,'Found ',count(is_Z_CPML),' Z_CPML elements'
  if (ALSO_ADD_ON_THE_TOP_SURFACE) print *,'    (also converted the top surface from free surface to CPML)'
  print *

  if (count(is_X_CPML) == 0 .or. count(is_Y_CPML) == 0 .or. count(is_Z_CPML) == 0) &
    stop 'error: no CPML elements detected on at least one of the sides!'

  number_of_CPML_elements = 0
  do ispec=1,nspec
    if (is_X_CPML(ispec) .or. is_Y_CPML(ispec) .or. is_Z_CPML(ispec)) &
          number_of_CPML_elements = number_of_CPML_elements + 1
  enddo
  print *,'Created a total of ',number_of_CPML_elements,' unique CPML elements'
  print *,'   (i.e., ',100.*number_of_CPML_elements/real(nspec),'% of the mesh)'

! ************* generate the CPML database file *************

  open(unit=24,file='absorbing_cpml_file',status='unknown',action='write')

! write the total number of unique CPML elements
  write(24,*) number_of_CPML_elements

! write the CPML flag for each CPML element
  do ispec=1,nspec
    if (is_X_CPML(ispec) .and. is_Y_CPML(ispec) .and. is_Z_CPML(ispec)) then
      write(24,*) ispec,CPML_XYZ

    else if (is_Y_CPML(ispec) .and. is_Z_CPML(ispec)) then
      write(24,*) ispec,CPML_YZ_ONLY

    else if (is_X_CPML(ispec) .and. is_Z_CPML(ispec)) then
      write(24,*) ispec,CPML_XZ_ONLY

    else if (is_X_CPML(ispec) .and. is_Y_CPML(ispec)) then
      write(24,*) ispec,CPML_XY_ONLY

    else if (is_Z_CPML(ispec)) then
      write(24,*) ispec,CPML_Z_ONLY

    else if (is_Y_CPML(ispec)) then
      write(24,*) ispec,CPML_Y_ONLY

    else if (is_X_CPML(ispec)) then
      write(24,*) ispec,CPML_X_ONLY
    endif

  enddo
  close(24)

  print *
  print *,'CPML absorbing layer file "absorbing_cpml_file" has been successfully created'
  print *

! ************* generate "absorbing_surface_file_xmin" *************

! first count the number of faces that are along that edge

  count_faces_found = 0

! Xmin CPML
  size_of_model = xmax - xmin
  limit = xmin + SMALL_RELATIVE_VALUE*size_of_model

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_X_CPML(ispec)) then

      already_found_a_face = .false.

! test face 1 (bottom)
      if (x(i1) < limit .and. x(i2) < limit .and. x(i3) < limit .and. x(i4) < limit) then
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 2 (top)
      if (x(i5) < limit .and. x(i6) < limit .and. x(i7) < limit .and. x(i8) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 3 (left)
      if (x(i1) < limit .and. x(i4) < limit .and. x(i8) < limit .and. x(i5) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 4 (right)
      if (x(i2) < limit .and. x(i3) < limit .and. x(i7) < limit .and. x(i6) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 5 (front)
      if (x(i1) < limit .and. x(i2) < limit .and. x(i6) < limit .and. x(i5) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 6 (back)
      if (x(i4) < limit .and. x(i3) < limit .and. x(i7) < limit .and. x(i8) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

    endif

  enddo

  print *,'found ',count_faces_found,' full faces on PML face Xmin'

!-----------------------------

! open SPECFEM3D_Cartesian topology file to read the mesh elements
  open(unit=24,file='absorbing_surface_file_xmin',status='unknown',action='write')

! write the total number of face elements
  write(24,*) count_faces_found

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_X_CPML(ispec)) then

! for the six faces below it is important to make sure we write the four points
! in an order for which the normal to the face points outwards

! test face 1 (bottom)
      if (x(i1) < limit .and. x(i2) < limit .and. x(i3) < limit .and. x(i4) < limit) &
        write(24,*) ispec,i4,i3,i2,i1

! test face 2 (top)
      if (x(i5) < limit .and. x(i6) < limit .and. x(i7) < limit .and. x(i8) < limit) &
        write(24,*) ispec,i5,i6,i7,i8

! test face 3 (left)
      if (x(i1) < limit .and. x(i4) < limit .and. x(i8) < limit .and. x(i5) < limit) &
        write(24,*) ispec,i1,i5,i8,i4

! test face 4 (right)
      if (x(i2) < limit .and. x(i3) < limit .and. x(i7) < limit .and. x(i6) < limit) &
        write(24,*) ispec,i2,i3,i7,i6

! test face 5 (front)
      if (x(i1) < limit .and. x(i2) < limit .and. x(i6) < limit .and. x(i5) < limit) &
        write(24,*) ispec,i1,i2,i6,i5

! test face 6 (back)
      if (x(i4) < limit .and. x(i3) < limit .and. x(i7) < limit .and. x(i8) < limit) &
        write(24,*) ispec,i3,i4,i8,i7

    endif

  enddo

  close(24)

  print *,'CPML file "absorbing_surface_file_xmin" has been successfully created'
  print *

! ************* generate "absorbing_surface_file_xmax" *************

! first count the number of faces that are along that edge

  count_faces_found = 0

! Xmax CPML
  size_of_model = xmax - xmin
  limit = xmax - SMALL_RELATIVE_VALUE*size_of_model

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_X_CPML(ispec)) then

      already_found_a_face = .false.

! test face 1 (bottom)
      if (x(i1) > limit .and. x(i2) > limit .and. x(i3) > limit .and. x(i4) > limit) then
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 2 (top)
      if (x(i5) > limit .and. x(i6) > limit .and. x(i7) > limit .and. x(i8) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 3 (left)
      if (x(i1) > limit .and. x(i4) > limit .and. x(i8) > limit .and. x(i5) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 4 (right)
      if (x(i2) > limit .and. x(i3) > limit .and. x(i7) > limit .and. x(i6) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 5 (front)
      if (x(i1) > limit .and. x(i2) > limit .and. x(i6) > limit .and. x(i5) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 6 (back)
      if (x(i4) > limit .and. x(i3) > limit .and. x(i7) > limit .and. x(i8) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

    endif

  enddo

  print *,'found ',count_faces_found,' full faces on PML face Xmax'

!-----------------------------

  open(unit=24,file='absorbing_surface_file_xmax',status='unknown',action='write')

! write the total number of face elements
  write(24,*) count_faces_found

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_X_CPML(ispec)) then

! for the six faces below it is important to make sure we write the four points
! in an order for which the normal to the face points outwards

! test face 1 (bottom)
      if (x(i1) > limit .and. x(i2) > limit .and. x(i3) > limit .and. x(i4) > limit) &
        write(24,*) ispec,i4,i3,i2,i1

! test face 2 (top)
      if (x(i5) > limit .and. x(i6) > limit .and. x(i7) > limit .and. x(i8) > limit) &
        write(24,*) ispec,i5,i6,i7,i8

! test face 3 (left)
      if (x(i1) > limit .and. x(i4) > limit .and. x(i8) > limit .and. x(i5) > limit) &
        write(24,*) ispec,i1,i5,i8,i4

! test face 4 (right)
      if (x(i2) > limit .and. x(i3) > limit .and. x(i7) > limit .and. x(i6) > limit) &
        write(24,*) ispec,i2,i3,i7,i6

! test face 5 (front)
      if (x(i1) > limit .and. x(i2) > limit .and. x(i6) > limit .and. x(i5) > limit) &
        write(24,*) ispec,i1,i2,i6,i5

! test face 6 (back)
      if (x(i4) > limit .and. x(i3) > limit .and. x(i7) > limit .and. x(i8) > limit) &
        write(24,*) ispec,i3,i4,i8,i7

    endif

  enddo

  close(24)

  print *,'CPML file "absorbing_surface_file_xmax" has been successfully created'
  print *

! ************* generate "absorbing_surface_file_ymin" *************

! first count the number of faces that are along that edge

  count_faces_found = 0

! Ymin CPML
  size_of_model = ymax - ymin
  limit = ymin + SMALL_RELATIVE_VALUE*size_of_model

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_Y_CPML(ispec)) then

      already_found_a_face = .false.

! test face 1 (bottom)
      if (y(i1) < limit .and. y(i2) < limit .and. y(i3) < limit .and. y(i4) < limit) then
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 2 (top)
      if (y(i5) < limit .and. y(i6) < limit .and. y(i7) < limit .and. y(i8) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 3 (left)
      if (y(i1) < limit .and. y(i4) < limit .and. y(i8) < limit .and. y(i5) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 4 (right)
      if (y(i2) < limit .and. y(i3) < limit .and. y(i7) < limit .and. y(i6) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 5 (front)
      if (y(i1) < limit .and. y(i2) < limit .and. y(i6) < limit .and. y(i5) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 6 (back)
      if (y(i4) < limit .and. y(i3) < limit .and. y(i7) < limit .and. y(i8) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

    endif

  enddo

  print *,'found ',count_faces_found,' full faces on PML face Ymin'

!-----------------------------

  open(unit=24,file='absorbing_surface_file_ymin',status='unknown',action='write')

! write the total number of face elements
  write(24,*) count_faces_found

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_Y_CPML(ispec)) then

! for the six faces below it is important to make sure we write the four points
! in an order for which the normal to the face points outwards

! test face 1 (bottom)
      if (y(i1) < limit .and. y(i2) < limit .and. y(i3) < limit .and. y(i4) < limit) &
        write(24,*) ispec,i4,i3,i2,i1

! test face 2 (top)
      if (y(i5) < limit .and. y(i6) < limit .and. y(i7) < limit .and. y(i8) < limit) &
        write(24,*) ispec,i5,i6,i7,i8

! test face 3 (left)
      if (y(i1) < limit .and. y(i4) < limit .and. y(i8) < limit .and. y(i5) < limit) &
        write(24,*) ispec,i1,i5,i8,i4

! test face 4 (right)
      if (y(i2) < limit .and. y(i3) < limit .and. y(i7) < limit .and. y(i6) < limit) &
        write(24,*) ispec,i2,i3,i7,i6

! test face 5 (front)
      if (y(i1) < limit .and. y(i2) < limit .and. y(i6) < limit .and. y(i5) < limit) &
        write(24,*) ispec,i1,i2,i6,i5

! test face 6 (back)
      if (y(i4) < limit .and. y(i3) < limit .and. y(i7) < limit .and. y(i8) < limit) &
        write(24,*) ispec,i3,i4,i8,i7

    endif

  enddo

  close(24)

  print *,'CPML file "absorbing_surface_file_ymin" has been successfully created'
  print *

! ************* generate "absorbing_surface_file_ymax" *************

! first count the number of faces that are along that edge

  count_faces_found = 0

! Ymax CPML
  size_of_model = ymax - ymin
  limit = ymax - SMALL_RELATIVE_VALUE*size_of_model

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_Y_CPML(ispec)) then

      already_found_a_face = .false.

! test face 1 (bottom)
      if (y(i1) > limit .and. y(i2) > limit .and. y(i3) > limit .and. y(i4) > limit) then
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 2 (top)
      if (y(i5) > limit .and. y(i6) > limit .and. y(i7) > limit .and. y(i8) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 3 (left)
      if (y(i1) > limit .and. y(i4) > limit .and. y(i8) > limit .and. y(i5) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 4 (right)
      if (y(i2) > limit .and. y(i3) > limit .and. y(i7) > limit .and. y(i6) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 5 (front)
      if (y(i1) > limit .and. y(i2) > limit .and. y(i6) > limit .and. y(i5) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 6 (back)
      if (y(i4) > limit .and. y(i3) > limit .and. y(i7) > limit .and. y(i8) > limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

    endif

  enddo

  print *,'found ',count_faces_found,' full faces on PML face Ymax'

!-----------------------------

  open(unit=24,file='absorbing_surface_file_ymax',status='unknown',action='write')

! write the total number of face elements
  write(24,*) count_faces_found

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_Y_CPML(ispec)) then

! for the six faces below it is important to make sure we write the four points
! in an order for which the normal to the face points outwards

! test face 1 (bottom)
      if (y(i1) > limit .and. y(i2) > limit .and. y(i3) > limit .and. y(i4) > limit) &
        write(24,*) ispec,i4,i3,i2,i1

! test face 2 (top)
      if (y(i5) > limit .and. y(i6) > limit .and. y(i7) > limit .and. y(i8) > limit) &
        write(24,*) ispec,i5,i6,i7,i8

! test face 3 (left)
      if (y(i1) > limit .and. y(i4) > limit .and. y(i8) > limit .and. y(i5) > limit) &
        write(24,*) ispec,i1,i5,i8,i4

! test face 4 (right)
      if (y(i2) > limit .and. y(i3) > limit .and. y(i7) > limit .and. y(i6) > limit) &
        write(24,*) ispec,i2,i3,i7,i6

! test face 5 (front)
      if (y(i1) > limit .and. y(i2) > limit .and. y(i6) > limit .and. y(i5) > limit) &
        write(24,*) ispec,i1,i2,i6,i5

! test face 6 (back)
      if (y(i4) > limit .and. y(i3) > limit .and. y(i7) > limit .and. y(i8) > limit) &
        write(24,*) ispec,i3,i4,i8,i7

    endif

  enddo

  close(24)

  print *,'CPML file "absorbing_surface_file_ymax" has been successfully created'
  print *

! ************* generate "absorbing_surface_file_bottom" *************

! first count the number of faces that are along that edge

  count_faces_found = 0

! Zmin CPML
  size_of_model = zmax - zmin
  limit = zmin + SMALL_RELATIVE_VALUE*size_of_model

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_Z_CPML(ispec)) then

      already_found_a_face = .false.

! test face 1 (bottom)
      if (z(i1) < limit .and. z(i2) < limit .and. z(i3) < limit .and. z(i4) < limit) then
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 2 (top)
      if (z(i5) < limit .and. z(i6) < limit .and. z(i7) < limit .and. z(i8) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 3 (left)
      if (z(i1) < limit .and. z(i4) < limit .and. z(i8) < limit .and. z(i5) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 4 (right)
      if (z(i2) < limit .and. z(i3) < limit .and. z(i7) < limit .and. z(i6) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 5 (front)
      if (z(i1) < limit .and. z(i2) < limit .and. z(i6) < limit .and. z(i5) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

! test face 6 (back)
      if (z(i4) < limit .and. z(i3) < limit .and. z(i7) < limit .and. z(i8) < limit) then
        if (already_found_a_face) stop 'error: element with two faces on the same PML edge found!'
        count_faces_found = count_faces_found + 1
        already_found_a_face = .true.
      endif

    endif

  enddo

  print *,'found ',count_faces_found,' full faces on PML face Zmin'

!-----------------------------

  open(unit=24,file='absorbing_surface_file_bottom',status='unknown',action='write')

! write the total number of face elements
  write(24,*) count_faces_found

! loop on the whole mesh
  do ispec = 1,nspec

    i1 = ibool(1,ispec)
    i2 = ibool(2,ispec)
    i3 = ibool(3,ispec)
    i4 = ibool(4,ispec)
    i5 = ibool(5,ispec)
    i6 = ibool(6,ispec)
    i7 = ibool(7,ispec)
    i8 = ibool(8,ispec)

    if (is_Z_CPML(ispec)) then

! for the six faces below it is important to make sure we write the four points
! in an order for which the normal to the face points outwards

! test face 1 (bottom)
      if (z(i1) < limit .and. z(i2) < limit .and. z(i3) < limit .and. z(i4) < limit) &
        write(24,*) ispec,i4,i3,i2,i1

! test face 2 (top)
      if (z(i5) < limit .and. z(i6) < limit .and. z(i7) < limit .and. z(i8) < limit) &
        write(24,*) ispec,i5,i6,i7,i8

! test face 3 (left)
      if (z(i1) < limit .and. z(i4) < limit .and. z(i8) < limit .and. z(i5) < limit) &
        write(24,*) ispec,i1,i5,i8,i4

! test face 4 (right)
      if (z(i2) < limit .and. z(i3) < limit .and. z(i7) < limit .and. z(i6) < limit) &
        write(24,*) ispec,i2,i3,i7,i6

! test face 5 (front)
      if (z(i1) < limit .and. z(i2) < limit .and. z(i6) < limit .and. z(i5) < limit) &
        write(24,*) ispec,i1,i2,i6,i5

! test face 6 (back)
      if (z(i4) < limit .and. z(i3) < limit .and. z(i7) < limit .and. z(i8) < limit) &
        write(24,*) ispec,i3,i4,i8,i7

    endif

  enddo

  close(24)

  print *,'CPML file "absorbing_surface_file_bottom" has been successfully created'
  print *

  end program convert_mesh_to_CPML

