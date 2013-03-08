!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! SHUFFLED COMPLEX EVOLUTION
!   Parameter optimisation algorithm based on a paper by Duan et al.
!   (1993, J. Opt. Theory and Appl., 76, 501--521).
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! VERSION 2.1 ---  01 February 1999
! Written by Neil Viney, Centre for Water Research (CWR), The University of WA
! Modified by Stan Schymanski, CWR, 05 April 2004 (to run with transpmodel)
! Extended by Stan Schymanski, SESE, 02 June 2006 to follow Muttil & Liong
! (2004, Journal of Hydraulic Engineering-Asce 130(12):1202-1205) and
! Duan et al. (1994, Journal of Hydrology 158)
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! This implementation MAXIMISES the objective function, which is
! calculated by the model, not by the optimiser. The optimiser transfers
! parameter values to the model subroutine and receives the value of the
! objective function.
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! Copyright (C) 2008 Stan Schymanski
!
!   This program is free software: you can redistribute it and/or modify
!   it under the terms of the GNU General Public License as published by
!   the Free Software Foundation, either version 3 of the License, or
!   (at your option) any later version.
!
!   This program is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
!   GNU General Public License for more details.
!
!   You should have received a copy of the GNU General Public License
!   along with this program. If not, see <http://www.gnu.org/licenses/>.
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine sce_main ()
      use vom_sce_mod
      implicit none

      INTEGER             :: i_, first, numcv
      REAL*8              :: maxcv
      REAL*8, ALLOCATABLE :: sumvar(:)
      CHARACTER(300)      :: writeformat
      INTEGER             :: run_initialseed
      CHARACTER(len=135)  :: msg
      integer             :: tmp2(2)
      character(len=9)    :: tmp3(1)

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! INITIALIZATION

      call sce_init(run_initialseed)

      allocate(sumvar(nopt))

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! BEGIN MODEL LOOP (EXECUTE s PASSES)
! CALL model SUBROUTINE        (OPEN run.log FOR CONSOLE OUTPUT);
! CALCULATE OBJECTIVE FUNCTION FOR DEFAULT PARAMETER VALUES
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

      if (run_initialseed == 1) then
        call initialseed
        return
      endif

!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! BEGIN SCE LOOP

      do while (nrun .lt. 20000 .and. nloop .lt. 500)

          nloop = nloop + 1

!         * Saving the best OF of the worst complex in worstbest for
!         * assessment of gene pool mixing

          first = 1 + (ncomp2 - 1) * mopt
          worstbest = ofvec(first)
!         * [SORT ENTIRE ARRAYS]
!         * use temporary variable to prevent warning in ifort
          tmp2(:) = shape(shufflevar(:,:))
          call sortcomp(shufflevar(:,:), tmp2(:), ofvec(:), SIZE(ofvec(:)))

!         * WRITE BEST_PARAMETERS FILE FOR PREVIOUS LOOP

          writeformat = '("Finished ",i4," main loops'
          writeformat(29:66) = ' --- best objective function =",e12.6)'
          write(msg,writeformat) nloop, ofvec(1)
          write(kfile_progress,*) TRIM(msg)
          write(kfile_progress,*) " "
          writeformat = '("No improvement in OF for",i5," loops")'
          write(msg,writeformat) nsincebest
          write(kfile_progress,*) TRIM(msg)
          nsincebest = nsincebest + 1

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! ASSESS CONVERGENCE
! CHANGED BY STAN TO CALCULATE THE FLUCTUATION RANGE RELATIVELY TO
! THE FEASIBLE RANGE, INSTEAD OF CV:

          numcv = ncomp2 * mopt
          sumvar(:) = sum(shufflevar(optid(:), 1:numcv),2) / numcv  ! mean parameter values
          do i_ = 1, nopt
!           * distance from mean in % of feasible range
            cv_(i_) = maxval(abs((shufflevar(optid(i_), 1:numcv) - sumvar(i_)) &
     &              / (parmin(optid(i_)) - parmax(optid(i_)))) * 100.d0)
          enddo
          maxcv = maxval(cv_(:))             ! maximum distance
          writeformat = '("Greatest parameter range: ",f5.2,"%'
          writeformat(38:67) = ' for optimised parameter ",a9)'
!         * use temporary variable to prevent warning in ifort
          tmp3(:) = parname(optid(maxloc(cv_(:))))
          write(msg,writeformat) maxcv, tmp3
          write(kfile_progress,*) TRIM(msg)
          if (maxcv .ge. resolution) then
            if (nsincebest .le. patience) then
              call writepars
              call run_cce()
              return
            else
              write(kfile_progress,*) " "
              writeformat = '("No improvement in OF for",i5," loops")'
              write(msg,writeformat) nsincebest
              write(kfile_progress,*) TRIM(msg)
              write(kfile_progress,*) "  About to give up..."
            endif
          else
            write(kfile_progress,*) " "
            write(kfile_progress,*) "First Convergence criterion satisfied..."
            write(kfile_progress,*) "  parameter ranges are all less than 0.1 %"
            write(kfile_progress,*) " "
            write(kfile_progress,*) " "
          endif

!       * STAN'S MODIFICATION TO ASSESS SENSITIVITY OF OBJECTIVE
!       * FUNCTION TO EACH PARAMETER:

          call ck_success()

          if (success .eq. 1) then
            return
          endif
      enddo

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! TERMINATE PROGRAM

          write(kfile_progress,*) " "
          write(kfile_progress,*) "FAILURE TO CONVERGE..."
          write(kfile_progress,*) "  Number of runs has reached 20000."
          write(kfile_progress,*) " "
          write(kfile_progress,*) "  Program terminated."
          write(msg,'(A,A)') char(7), char(7)
          write(kfile_progress,*) TRIM(msg)
!         * [SORT ENTIRE ARRAYS]
!         * use temporary variable to prevent warning in ifort
          tmp2(:) = shape(shufflevar(:,:))
          call sortcomp(shufflevar(:,:), tmp2(:), ofvec(:), SIZE(ofvec(:)))
          call writepars()                     ! PROGRAM STOP
          open(kfile_finalbest, FILE=sfile_finalbest)
            write(kfile_finalbest,outformat) shufflevar(:,1), bestobj
          close(kfile_finalbest)
          close(kfile_sceout)
          close(kfile_bestpars)
          close(kfile_progress)

      deallocate(sumvar)

      return
      end subroutine sce_main

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine sce_init (run_initialseed)
      use vom_sce_mod
      implicit none

      INTEGER, INTENT(out) :: run_initialseed

      INTEGER       :: i_, j_
      CHARACTER(3)  :: str
      CHARACTER(24)       :: logdate
      character(len=135)  :: msg

      call read_shufflepar()

!EXTERNAL compar
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! Initialize the random number generator
! (standard subroutine, based on the date and time)
      if (command .ne. 4) then
        CALL RANDOM_SEED()
      endif

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! WRITE SCREEN HEADER

      write(*,*) 'SHUFFLED COMPLEX EVOLUTION OPTIMISER'
      call fdate(logdate)
      write(*,*) " "
      write(msg,'("  Run time:   ",A)') logdate
      write(*,*) TRIM(msg)

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! READ PARAMETER FILE shufflevar

      call read_shufflevar()

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! CALCULATE NUMBER OF OPTIMISABLE PARAMETERS

      nopt = sum(paropt(:))
      mopt = 2 * nopt + 1                         ! SCE VARIABLE m
      ncomp = MAX(ncomp, Ceiling(1.d0 + 2.d0 ** nopt / (1.d0 + 2.d0 * nopt)))  ! number of complexes after Muttil(2004) or from shuffle.par
      sopt = mopt * ncomp                         ! SCE VARIABLE s
      qopt = nopt + 1                             ! CCE VARIABLE q
      ncomp2 = ncomp

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! ALLOCATE GLOBAL FIELDS

      allocate(optid(nopt))
      allocate(shufflevar(npar,sopt))
      allocate(ofvec(sopt))
      allocate(wgt(mopt))
      allocate(cv_(nopt))
      allocate(ranarr(nopt))
      allocate(dataarray(nopt*8+1,nopt+1))
      allocate(shufflevar2(npar))
      allocate(parentsid(qopt))
      allocate(objfunsub(qopt))
      allocate(invarsub(npar,qopt))
      allocate(selected(mopt))
      allocate(centroid(npar))
      allocate(newpoint(npar))

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! INITIALISE OUTPUT FORMAT STRING
! INTRODUCED BY STAN TO HAVE ONE COLUMN PER PARAMETER AND ONE FOR OF

      write(str,'(i2)') npar + 1                  ! internal write to convert from integer to string
      outformat = '('//str//'e24.15)'             ! includes a column for each parameter and a column for the value of OF

!     * ADDED BY STAN TO WRITE shufflevar AND ofvec OF LAST LOOP TO FILE
      write(str,'(i3)') sopt                      ! internal write to convert from number to string
      loopformat = '('//str//'e24.15)'            ! includes a column for each set

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! INITIALISE optid: THE INDEX OF THOSE PARAMETERS THAT ARE OPTIMISABLE

      j_ = 0
      do i_ = 1, npar
        if (paropt(i_) .gt. 0) then
          j_ = j_ + 1
          optid(j_) = i_
        endif
      enddo

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! INITIALISE optid: THE INDEX OF THOSE PARAMETERS THAT ARE OPTIMISABLE
! ASSIGN PROBABILITY WEIGHTS

      do i_ = 1, mopt
        wgt(i_) = 2.d0 * (mopt + 1.d0 - i_) / mopt / (mopt + 1.d0)
      enddo

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! INSERTED BY STAN TO ALLOW CONTINUATION OF OPTIMSATION FROM PREVIOUSLY SAVED STEP

      call open_output (logdate, run_initialseed)

      return
      end subroutine sce_init

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine read_shufflepar ()
      use vom_sce_mod
      implicit none

      CHARACTER(3)  :: str
      INTEGER       :: ios

      open(kfile_shufflepar, FILE=sfile_shufflepar, STATUS='old')

      read(kfile_shufflepar,*)
      read(kfile_shufflepar,*)
      npar = 0
      do
        read(kfile_shufflepar,*,IOSTAT=ios) str
        if (ios .lt. 0) exit
        if (str .eq. 'var') npar = npar + 1
      enddo
      rewind(kfile_shufflepar)

!     * Input of variable parameters from the parameter file
      read(kfile_shufflepar,'(i1)') command
      read(kfile_shufflepar,*) ncomp
      read(kfile_shufflepar,*) ncompmin
      read(kfile_shufflepar,*) resolution
      read(kfile_shufflepar,*) patience
      read(kfile_shufflepar,*) nsimp
      read(kfile_shufflepar,*) focus

      return
      end subroutine read_shufflepar

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine read_shufflevar ()
      use vom_sce_mod
      implicit none

      INTEGER       :: i_
      CHARACTER(60) :: informat

!     * LOAD INITIAL PARAMETER VALUES AND PARAMETER RANGES

!     * allocate the parameter fields

      allocate(parname(npar))
      allocate(parval(npar))
      allocate(parmin(npar))
      allocate(parmax(npar))
      allocate(paropt(npar))

      read(kfile_shufflepar,'(a60)') informat
      do i_ = 1, npar
        read(kfile_shufflepar,informat) parname(i_), parval(i_), parmin(i_), &
     &                                  parmax(i_), paropt(i_)
      enddo
      close(kfile_shufflepar)

      return
      end subroutine read_shufflevar

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine open_output (logdate, run_initialseed)
      use vom_sce_mod
      implicit none

      CHARACTER(24), INTENT(in) :: logdate
      INTEGER,      INTENT(out) :: run_initialseed

      INTEGER :: i_, iostat
      CHARACTER(len=135) :: msg
      real*8, allocatable :: tmp(:)

      run_initialseed = 0

      open(kfile_lastloop, FILE=sfile_lastloop, STATUS='old', IOSTAT=iostat)
      if (iostat .eq. 0) then
        read(kfile_lastloop,*) ncomp2
        read(kfile_lastloop,*) nloop
        read(kfile_lastloop,*) nrun
        read(kfile_lastloop,*) nsincebest
        read(kfile_lastloop,loopformat) ofvec(:)
!       * use temporary variable to prevent warning in ifort
        allocate(tmp(sopt))
        do i_ = 1, npar
          read(kfile_lastloop, loopformat) tmp(:)
          shufflevar(i_,:) = tmp(:)
        enddo
        deallocate(tmp)
        close(kfile_lastloop)
        bestobj = ofvec(1)

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! OPEN FILES FOR STORING OBJECTIVE FUNCTION AND PARAMETER VALUES

          open(kfile_sceout, FILE=sfile_sceout, STATUS='old', POSITION='append')
        open(kfile_bestpars, FILE=sfile_bestpars, STATUS='old', POSITION='append')
          open(kfile_progress, FILE=sfile_progress, STATUS='old', POSITION='append')
        write(kfile_progress,*) " "
        write(msg,'("  NEW Run time:   ",A)') logdate
        write(kfile_progress,*) TRIM(msg)
      else

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! OPEN AND EMPTY FILE FOR STORING OBJECTIVE FUNCTION AND PARAMETER VALUES

          open(kfile_sceout, FILE=sfile_sceout, STATUS='replace')
        open(kfile_bestpars, FILE=sfile_bestpars, STATUS='replace')
          open(kfile_progress, FILE=sfile_progress, STATUS='replace')

!       * write file header
        write(kfile_progress,*) 'SHUFFLED COMPLEX EVOLUTION OPTIMISER'
        write(kfile_progress,*) " "
        write(msg,'("  Run time:   ",A)') logdate
        write(kfile_progress,*) TRIM(msg)

        run_initialseed = 1
      endif

      return
      end subroutine open_output

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine initialseed ()
      use vom_sce_mod
      implicit none

      INTEGER       :: i_
      INTEGER       :: j_, k_
      INTEGER       :: worstcount       ! worstcount for counting number of negative objective functions
      character(len=135) :: msg

      INTEGER, ALLOCATABLE :: posarray(:,:)
      REAL*8,  ALLOCATABLE :: initpop(:,:)

      allocate(posarray(2**nopt,nopt))
      allocate(initpop(nopt,5))

      do i_ = 1,sopt

        if (i_ .eq. 1) then

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! PRINT DIMENSION INFORMATION

      write(kfile_progress,*) '  Number of model parameters:         ',npar
      write(kfile_progress,*) '  Number of optimisable parameters:   ',nopt
      write(kfile_progress,*) '  Maximum number of complexes:        ',ncomp
      write(kfile_progress,*) '  Minimum number of runs per complex: ',mopt

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! CALCULATING OF USING INITAL GUESS IN SHUFFLE.PAR

            nsincebest = 0
            evolution = 'seed'
            ofvec(:) = -9999.9d0
            shufflevar(:,1) = parval(:)
            nrun = 0
            worstcount = 0

          call runmodel(shufflevar(:,1), ofvec(1))

            if (ofvec(1) .le. 0.d0) worstcount = worstcount + 1
            bestobj = ofvec(1)
            bestincomp = bestobj
            open(kfile_currentbest, FILE=sfile_currentbest)
              write(kfile_currentbest,outformat) shufflevar(:,1), bestobj
            close(kfile_currentbest)
            write(msg,'("Systematic seed of",i4," parameters for ",i2," complexes. Initial OF= ",e13.6)') nopt, ncomp, ofvec(1)
            write(6,*) TRIM(msg)

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
! GENERATE A SYSTEMATIC ARRAY OF INITIAL PARAMETER VALUES FOLLOWING
! Muttil & Liong (2004, Journal of Hydraulic Engineering-Asce 130(12):1202-1205
! (INSERTED BY STAN)
!
! NONAXIAL POINTS:

            posarray(1,1) = 1
            posarray(2,1) = 2
            do j_ = 1, nopt
              k_ = optid(j_)
!             * each position j contains the intial perturbation of an optimised parameter
              initpop(j_,1) = 0.125d0 * parmax(k_) + 0.875d0 * parmin(k_)
              initpop(j_,2) = 0.125d0 * parmin(k_) + 0.875d0 * parmax(k_)
              initpop(j_,3) = 0.5d0 * (parmin(k_) + parmax(k_))
              initpop(j_,4) = 0.25d0 * parmax(k_) + 0.75d0 * parmin(k_)
              initpop(j_,5) = 0.25d0 * parmin(k_) + 0.75d0 * parmax(k_)
              posarray(2**(j_-1)+1:2**j_, 1:j_-1) = posarray(1:2**(j_-1), 1:j_-1)
              posarray(1:2**(j_-1), j_) = 1
              posarray(2**(j_-1)+1:2**j_, j_) = 2
            enddo
        endif

        if (i_ .gt. 1) then
            shufflevar(:,i_) = parval(:)   ! TO SET NON-OPTIMISING PARAMETERS
        endif

        if (i_ .gt. 1 .and. i_ .le. 4) then
            do j_ = 1, nopt
              k_ = optid(j_)
              shufflevar(k_,i_) = initpop(j_,i_+1)
            enddo

          call runmodel(shufflevar(:,i_), ofvec(i_))

            if (ofvec(i_) .le. 0) worstcount = worstcount + 1
        endif

        if (i_ .gt. 4 .and. i_ .le. SIZE(posarray(:,:),1)) then
            do j_ = 1, nopt
              k_ = optid(j_)
              shufflevar(k_,i_) = initpop(j_, posarray(i_-4, j_))
            enddo

          call runmodel(shufflevar(:,i_), ofvec(i_))

            if (ofvec(i_) .le. 0) worstcount = worstcount + 1
        endif

!       * IF MORE POINTS ARE NEEDED, GENERATE RANDOM POINTS

        if (i_ .gt. SIZE(posarray(:,:),1)) then
          evolution = 'mutation'

!         * first loop must generate feasible values to start with
          do while (ofvec(i_) .le. 0.d0)

              call random_number(ranarr(:))    ! RANDOM ARRAY OF SIZE 1:nopt
              do j_ = 1, nopt
                k_ = optid(j_)

!               * STAN'S MODIFICATION TO GET COMPLETELY RANDOM SEED:

                shufflevar(k_,i_) = parmin(k_) + focus * (parmax(k_) - parmin(k_)) * ranarr(j_)
              enddo
              shufflevar(optid(:),i_) = merge(shufflevar(optid(:),i_), parmin(optid(:)), &
     &                                  shufflevar(optid(:),i_) .gt. parmin(optid(:)))
              shufflevar(optid(:),i_) = merge(shufflevar(optid(:),i_), parmax(optid(:)), &
     &                                  shufflevar(optid(:),i_) .lt. parmax(optid(:)))

            call runmodel(shufflevar(:,i_), ofvec(i_))

              if (ofvec(i_) .le. 0) worstcount = worstcount + 1
!             * program stops after 100 runs without positive objective function
              if (nrun .gt. 100 .and. nrun .eq. worstcount) then
                success = 2
                call writepars()
                exit
              endif

          enddo

        endif

          if (ofvec(i_) .gt. bestobj) then
            bestobj = ofvec(i_)
            open(kfile_currentbest, FILE=sfile_currentbest)
              write(kfile_currentbest,outformat) shufflevar(:,i_), bestobj
            close(kfile_currentbest)
          endif

        if (success .eq. 2) exit
      enddo

        nloop = -1                           ! FIRST LOOP IS LOOP ZERO
        call writeloop()
        close(kfile_sceout)
        close(kfile_bestpars)
        close(kfile_progress)

      deallocate(posarray)
      deallocate(initpop)

      return
      end subroutine initialseed

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine ck_success ()
      use vom_sce_mod
      implicit none

      integer :: tmp2(2)

      call optsensitivity()

        if (success .eq. 1) then
!         * [SORT ENTIRE ARRAYS]
!         * use temporary variable to prevent warning in ifort
          tmp2(:) = shape(shufflevar(:,:))
          call sortcomp(shufflevar(:,:), tmp2(:), ofvec(:), SIZE(ofvec(:)))
          call writepars()
          write(kfile_progress,*) 'Optimisation completed successfully.'
          close(kfile_sceout)
          close(kfile_bestpars)
          close(kfile_progress)
        else
!         * [SORT ENTIRE ARRAYS]
!         * use temporary variable to prevent warning in ifort
          tmp2(:) = shape(shufflevar(:,:))
          call sortcomp(shufflevar(:,:), tmp2(:), ofvec(:), SIZE(ofvec(:)))
          call writepars()
          nsincebest = 0
          write(kfile_bestpars,outformat) shufflevar(:,1), bestobj
        endif

      return
      end subroutine ck_success

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! ADDED BY STAN TO ASSESS SENSITIVITY OF OBJECTIVE FUNCTION TO EACH OPTIMISED
! PARAMETER:
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine optsensitivity ()
      use vom_sce_mod
      implicit none

      INTEGER       :: i_, j_, k_, failed10, pos
      REAL*8        :: distmin, distmax
      REAL*8        :: oldpar, newpar
      REAL*8        :: ofvec2, ofchange, parchange
      CHARACTER(300)       :: writeformat
      character(len=135)   :: msg
      real*8, allocatable  :: tmp(:)

        shufflevar2(:) = shufflevar(:,1)
        ofvec2 = ofvec(1)
        failed10 = 0

        write(kfile_progress,*) 'SENSITIVITY ANALYSIS'
        write(kfile_progress,*) 'changes in % of feasible range)'
        dataarray(1,1:nopt) = shufflevar2(optid(:))
        dataarray(1,nopt+1) = ofvec2
        evolution = 'test'
        pos = 0

      do i_ = 1, nopt

          oldpar = shufflevar2(optid(i_))

!         * TO MAKE SURE THAT PERTURBATIONS DO NOT EXCEED THE FEASIBLE RANGE
!         * AND THE PARAMETER VALUES THEMSELVES

          distmin = oldpar - parmin(optid(i_))
          distmax = parmax(optid(i_)) - oldpar
          write(kfile_progress,*) " "
          writeformat = '("change of var: ",A9, "(",E9.3,")")'
          write(msg,writeformat) parname(optid(i_)), oldpar
          write(kfile_progress,*) TRIM(msg)
          writeformat = '(f7.3,"% (",e14.7,")",": change of OF by ",'
          writeformat(44:68) = 'e10.3,"%"," (",e10.3,")")'

          j_ = 0  ! count from 0 to 3 and than from 3 to 0
          k_ = 1  ! counter first +1 after 3 it become -1

        do while (j_ .ge. 0)

            if (k_ .eq. 1) then
              newpar = oldpar - distmin * 10.d0 ** (-j_)
            else
              newpar = oldpar + distmax * 10.d0 ** (-j_)
            endif
            nrun = nrun + 1
            shufflevar2(optid(i_)) = newpar

          call transpmodel(shufflevar2(:), SIZE(shufflevar2(:)), ofvec2, 1)

            if (ofvec2 .gt. bestobj) then
              bestobj = ofvec2
              open(kfile_currentbest, FILE=sfile_currentbest)
                write(kfile_currentbest,outformat) shufflevar2(:), bestobj
              close(kfile_currentbest)
            endif

!             * use temporary variable to prevent warning in ifort
              allocate(tmp(nopt))
              tmp(:) = shufflevar2(optid(:))
              write(kfile_sceout,outformat) tmp(:), ofvec2
              deallocate(tmp)

            if (k_ .eq. 1) then
              dataarray((i_-1)*8+j_+2,1:nopt) = shufflevar2(optid(:))
              dataarray((i_-1)*8+j_+2,nopt+1) = ofvec2
            else
              dataarray((i_-1)*8+j_+6,1:nopt) = shufflevar2(optid(:))
              dataarray((i_-1)*8+j_+6,nopt+1) = ofvec2
            endif
            ofchange = (ofvec2 - dataarray(1,nopt + 1))                &
     &               / abs(dataarray(1,nopt + 1)) * 100.d0
            parchange = (newpar - oldpar) / (parmax(optid(i_))         &
     &                - parmin(optid(i_))) * 100.d0  ! the change of the parameter in % of feasible range
            write(msg,writeformat) parchange, newpar, ofchange, ofvec2
            write(kfile_progress,*) TRIM(msg)
            flush(kfile_progress)

            if (ofchange .gt. 1.0d-10) then
              shufflevar(:,sopt-pos) = shufflevar2(:)
              ofvec(sopt-pos) = ofvec2
              pos = pos + 1
              if (abs(parchange) .gt. resolution) then
                failed10 = failed10 + 1
              endif
            endif

            j_ = j_ + k_
            if (j_ .eq. 4) then
              j_ = 3
              k_ = -1
            endif
        enddo

          shufflevar2(optid(i_)) = oldpar

      enddo

!     * ASSESS SECOND CONVERGENCE CRITERIUM: NO PARAMETER CHANGE BY MORE THAN
!     * 10% LEADS TO AN INCREASE IN OBJECTIVE FUNCTION

        if (failed10 .gt. 0) then
          writeformat = '(I2," parameter(s) more than ",F6.3,"% out of optimum.")'
          write(msg,writeformat) failed10, resolution
          write(kfile_progress,*) TRIM(msg)
          write(kfile_progress,*) "Optimisation continued..."
        else
          write(kfile_progress,*) " "
          write(kfile_progress,*) " "
          write(kfile_progress,*) "Second convergence criterion satisfied:"
          writeformat = '("no parameter shift by more than ",F6.3,"% of max distance leads to")'
          write(msg,writeformat) resolution
          write(kfile_progress,*) TRIM(msg)
          write(kfile_progress,*) "an increase in the objective function."
          success = 1
        endif

!     * IF CRITERIUM NOT SATISFIED, APPEND NEWLY CREATED DATA TO THE END OF
!     * shufflevar AND ofvec ARRAYS AND RETURN TO MAIN LOOP TO RE-RUN SCE-LOOP
!     * --> deleted

      return
      end subroutine optsensitivity

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine run_cce ()
      use vom_sce_mod
      implicit none

      INTEGER              :: m_, first
      CHARACTER(300)       :: writeformat
      character(len=135)   :: msg

!     * PARTITION THE sopt POINTS INTO ncomp2 COMPLEXES
!     * EXECUTE CCE ALGORITHM

        if (ncomp2 .gt. 1) then
          if (nloop .gt. 0) then
            if (ncomp2 .gt. ncompmin) then
              ncomp2 = ncomp2 - 1            ! REDUCE NUMBER OF COMPLEXES AS nloop INCREASES
            else
              if (worstbest .le. ofvec(1+(ncomp2-1)*mopt)) then
                writeformat = '("No gene pool mixing ... '
                writeformat(27:64) = 'reducing number of complexes by one.")'
                write(msg,writeformat)
                write(kfile_progress,*) TRIM(msg)
                ncomp2 = ncomp2 - 1
              endif
            endif
          endif
        endif

      do m_ = 1, ncomp2

          first = 1 + (m_ - 1) * mopt
          writeformat = '("Start of loop",i4,", complex",i2,'
          writeformat(36:55) = '": best OF =",e12.6)'
          write(msg,writeformat) nloop + 1, m_, ofvec(first)
          write(kfile_progress,*) TRIM(msg)
          if (m_ .eq. 1) then
            bestincomp = -9999.d0                   ! SET LESS THAN bestobj
          else
            bestincomp = ofvec(first)
          endif

        call cce(ofvec(first:m_*mopt), shufflevar(:,first:m_*mopt))

          writeformat(3:7) = '  End'
          write(msg,writeformat) nloop + 1, m_, ofvec(first)
          write(kfile_progress,*) TRIM(msg)

      enddo

        worstbest = ofvec(first)

!       * WRITE shufflevar AND ofvec OF LAST LOOP TO FILE
        call writeloop()
        close(kfile_sceout)
        close(kfile_bestpars)
        close(kfile_progress)

      return
      end subroutine run_cce

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine cce (objfun, invar)
      use vom_sce_mod
      implicit none

!     * Declarations
      REAL*8, DIMENSION(mopt),      INTENT(inout) :: objfun
      REAL*8, DIMENSION(npar,mopt), INTENT(inout) :: invar

!     * Definitions
      INTEGER       :: l_
      INTEGER       :: i_, nsel, rannum
      INTEGER       :: tmp2(2)

!     * SELECT PARENTS

      do l_ = 1, mopt

          selected(:) = .false.
          nsel = 0
          do while (nsel .ne. qopt)
            call random_number(ranscal)      ! SCALAR RANDOM NUMBER
            rannum = ceiling((2.d0 * mopt + 1.d0 - sqrt(4.d0 * mopt    &
     &             * (mopt + 1.d0) * (1.d0 - ranscal) + 1.d0)) * 0.5d0)

!           * NOTE: A SIMPLER ALTERNATIVE TO THE ABOVE LINE IS (19.03.2004):

            if (rannum .ge. 1 .and. rannum .le. mopt) then
              if (.not. selected(rannum)) then
                selected(rannum) = .true.
                nsel = nsel + 1
              endif
            endif
          enddo
          nsel = 0
          i_ = 0
          do while (nsel .ne. qopt)
            i_ = i_ + 1
            if (selected(i_)) then
              nsel = nsel + 1
              parentsid(nsel) = i_
            endif
          enddo

!         * GENERATE OFFSPRING AND SORT THE RESULTING COMPLEX

          objfunsub(:) = objfun(parentsid(:))
          invarsub(:,:) = invar(:, parentsid(:))

        call simplex(invarsub(:,:), objfunsub(:))

          objfun(parentsid(:)) = objfunsub(:)
          invar(:, parentsid(:)) = invarsub(:,:)
!         * use temporary variable to prevent warning in ifort
          tmp2(:) = shape(invar)
          call sortcomp(invar, tmp2(:), objfun, SIZE(objfun))

      enddo

      return
      end subroutine cce

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine simplex (invar, objfun)
      use vom_sce_mod
      implicit none

!     * Declarations
      REAL*8, DIMENSION(npar,qopt), INTENT(inout) :: invar
      REAL*8, DIMENSION(qopt),      INTENT(inout) :: objfun

!     * Definitions
      INTEGER       :: l_, k_
      INTEGER       :: i_, j_
      INTEGER       :: max_j_
      REAL*8        :: newobjfun
      REAL*8        :: minj, rangej

      do l_ = 1, nsimp

!         * REFLECTION STEP

          evolution = 'reflection'
          newpoint(:) = invar(:,qopt)
          centroid(optid(:)) = 1.d0 / (qopt - 1) * sum(invar(optid(:), 1:qopt - 1), 2)
          newpoint(optid(:)) = 2.d0 * centroid(optid(:)) - invar(optid(:),qopt)
          if (minval(newpoint(:) - parmin(:)) .lt. 0.d0 .or.           &
     &        maxval(newpoint(:) - parmax(:)) .gt. 0.d0) then

!           * MUTATION STEP
!           * NB: MUTATION IS BASED ON THE SMALLEST HYPERCUBE OF THE SUBCOMPLEX,
!           * NOT THE SMALLEST HYPERCUBE OF THE COMPLEX AS SUGGESTED BY DUAN ET AL.

            do i_ = 1, nopt
              call random_number(ranscal)             ! SCALAR RANDOM NUMBER
              j_ = optid(i_)
              minj = parmin(j_)
              rangej = parmax(j_) - minj
              newpoint(j_) = minj + rangej * ranscal   ! UNIFORMLY DISTRIBUTED SAMPLE
            enddo
            evolution = 'mutation'
          endif

          k_ = 1
        do while (k_ .le. 3)

!         * CALCULATE OBJECTIVE FUNCTION
          call runmodel(newpoint(:), newobjfun)

            j_ = 1
            if (k_ .eq. 1) then
              if (newobjfun .gt. objfun(qopt)) then
                max_j_ = qopt
                k_ = 4
              else
!               * CONTRACTION STEP
                newpoint(optid(:)) = (centroid(optid(:)) + invar(optid(:),qopt)) * 0.5d0
                evolution = 'contraction'
              endif
            endif

            if (k_ .eq. 2) then
              if (newobjfun .gt. objfun(qopt)) then
                max_j_ = qopt
                k_ = 4
              else
!               * ANOTHER MUTATION STEP
                do i_ = 1, nopt
                  call random_number(ranarr(:))         ! RANDOM ARRAY OF SIZE 1:nopt
                  j_ = optid(i_)
                  minj = minval(invar(j_,:))
                  rangej = maxval(invar(j_,:)) - minj
                  newpoint(j_) = minj + rangej * ranarr(i_)  ! UNIFORMLY DISTRIBUTED SAMPLE
                enddo
                evolution = 'mutation'
              endif
            endif

            if (k_ .eq. 3) then
              if (newobjfun .gt. objfun(qopt-1)) then
                max_j_ = qopt - 1
                k_ = 4
              elseif (newobjfun .gt. 0.d0) then       ! REPLACE ANYWAY
                objfun(qopt) = newobjfun
                invar(:,qopt) = newpoint(:)
              endif
            endif

            if (k_ .eq. 4) then
!            * SORT objfun HERE IN CASE alpha > 1
              do while (newobjfun .le. objfun(j_) .and. j_ .le. max_j_)
                j_ = j_ + 1
              enddo
              if (j_ .lt. qopt) then
                objfun(j_+1:qopt) = objfun(j_:qopt-1)
                invar(:,j_+1:qopt) = invar(:,j_:qopt-1)
              endif
              if (j_ .le. qopt) then
                objfun(j_) = newobjfun
                invar(:,j_) = newpoint(:)
              endif
            endif

            k_ = k_ + 1

          enddo

!         * UPDATE 'currentbest' IF APPROPRIATE

          if (newobjfun .gt. bestobj) then
            bestobj = newobjfun
            bestincomp = newobjfun
            open(kfile_currentbest, FILE=sfile_currentbest)
              write(kfile_currentbest,outformat) invar(:,1), bestobj
            close(kfile_currentbest)
            nsincebest = 0
          elseif (newobjfun .gt. bestincomp) then
            bestincomp = newobjfun
          endif

      enddo

      return
      end subroutine simplex

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine runmodel (invar, objfun)
      use vom_sce_mod
      implicit none

!     * Declarations
      REAL*8, DIMENSION(npar), INTENT(in) :: invar
      REAL*8, INTENT(out) :: objfun

!     * Definitions
      CHARACTER(1)   :: bestmark
      CHARACTER(300) :: writeformat
      character(len=135) :: msg
      real*8, allocatable :: tmp(:)

        nrun = nrun + 1

      call transpmodel(invar(:), npar, objfun, 1)

        bestmark = ' '
        if (objfun .gt. bestobj) then
          bestmark = '+'
        elseif (objfun .gt. bestincomp) then
          bestmark = '.'
        endif
        if (evolution .ne. 'test') then
          writeformat = '("Run",i6,"  (",a,"):",t28,"OF =",e12.6,1x,a)'
          write(msg,writeformat) nrun, TRIM(evolution), objfun, bestmark
          write(kfile_progress,*) TRIM(msg)

!           * use temporary variable to prevent warning in ifort
            allocate(tmp(nopt))
            tmp(:) = invar(optid(:))
            write(kfile_sceout,outformat) tmp(:), objfun
            flush(kfile_progress)
            deallocate(tmp)
        endif

      return
      end subroutine runmodel

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine sortcomp (invar, dim_invar, objfun, dim_objfun)
      implicit none

!     * Declarations
      INTEGER, DIMENSION(2), INTENT(in) :: dim_invar
      REAL*8, DIMENSION(dim_invar(1),dim_invar(2)), INTENT(inout) :: invar
      INTEGER, INTENT(in) :: dim_objfun
      REAL*8, DIMENSION(dim_objfun), INTENT(inout) :: objfun

!     * Definitions
      INTEGER :: i_, j_(1)

      REAL*8,  DIMENSION(:),   ALLOCATABLE :: objfun2
      REAL*8,  DIMENSION(:,:), ALLOCATABLE :: invar2
      INTEGER, DIMENSION(:),   ALLOCATABLE :: newobjfun

      allocate(objfun2(dim_objfun))
      allocate(invar2(dim_invar(1),dim_invar(2)))
      allocate(newobjfun(dim_objfun))

!     * EXTERNAL compar

      objfun2(:) = objfun(:)
      newobjfun(:) = -99                          ! NEEDED TO SEPARATE EQUAL O.F. VALUES
      invar2(:,:) = invar(:,:)
!     call qsort(objfun(:), dim, 8, compar)       ! USE compar(b,c)=(c-b)/dabs(c-b)
      call qsort(objfun(:), dim_objfun)
      do i_ = 1, dim_objfun
        j_ = minloc(real(dabs(objfun2(:) - objfun(i_))), newobjfun(:) .lt. 0)
        newobjfun(j_(1)) = i_
        invar(:,i_) = invar2(:,j_(1))
      enddo

      deallocate(objfun2)
      deallocate(invar2)
      deallocate(newobjfun)

      return
      end subroutine sortcomp

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

!     * WRITE shufflevar AND ofvec OF LAST LOOP TO FILE AND TERMINATE
      subroutine writeloop ()
      use vom_sce_mod
      implicit none

      INTEGER :: i_
      real*8, allocatable :: tmp(:)

      open(kfile_lastloop, FILE=sfile_lastloop)
      write(kfile_lastloop,'(i3)') ncomp2
      write(kfile_lastloop,'(i4)') nloop
      write(kfile_lastloop,'(i10)') nrun
      write(kfile_lastloop,'(i10)') nsincebest
      write(kfile_lastloop,loopformat) ofvec(:)
      do i_ = 1, npar
!       * use temporary variable to prevent warning in ifort
        allocate(tmp(sopt))
        tmp(:) = shufflevar(i_,:)
        write(kfile_lastloop,loopformat) tmp(:)
        deallocate(tmp)
      enddo
      close(kfile_lastloop)

      return
      end subroutine writeloop

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      subroutine writepars ()
      use vom_sce_mod
      implicit none

      INTEGER :: i_
      character(len=135) :: msg

      write(kfile_progress,*) " "
      write(msg,'("PARAMETER|     VALUE   |    MINVAL   |    MAXVAL   |  CV (%)     ")')
      write(kfile_progress,*) TRIM(msg)
      do i_ = 1, nopt
        write(msg,'(a9,5e14.6)') parname(optid(i_)), shufflevar(optid(i_),1), parmin(optid(i_)), parmax(optid(i_)), cv_(i_)
        write(kfile_progress,*) TRIM(msg)
      enddo
      write(kfile_progress,*) ' '

      if (success .eq. 1) then
        open(kfile_finalbest, FILE=sfile_finalbest)
          write(kfile_finalbest,outformat) shufflevar(:,1), bestobj
        close(kfile_finalbest)
      endif

      if (success .eq. 2) then
        open(kfile_finalbest, FILE=sfile_finalbest)
          write(kfile_finalbest,'("   0.0E+00  0.0E+00  0.0E+00  0.0E+00  0.0E+00  0.0E+00  0.0E+00")')
        close(kfile_finalbest)
      endif

      return
      end subroutine writepars

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

!     * SORTS THE VECTOR OBJFUN IN DESCENDING ORDER AND RETURNS IT
      subroutine qsort (objfun, dim_objfun)
      implicit none

!     * Declarations
      INTEGER :: dim_objfun
      REAL*8, DIMENSION(dim_objfun), INTENT(inout) :: objfun

!     * Definitions
      INTEGER :: i_, j_, k_

      do i_ = 2, dim_objfun
        if (objfun(i_) .gt. objfun(i_-1)) then
          k_ = i_ - 2
          do j_ = i_ - 2, 1, -1
            k_ = j_
            if (objfun(i_) .lt. objfun(j_)) exit
            if (j_ .eq. 1) k_ = 0   ! If objfun(i_)>objfun(1), then cycle objfun(i_) to the top
          enddo
          objfun(k_+1:i_) = cshift(objfun(k_+1:i_), -1)
        endif
      enddo

! For debugging:
!$ do i_ = 1, dim_objfun
!$  print *, objfun(i_)
!$ enddo

      return
      end subroutine qsort

!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

!$INTEGER function compar(b,c)
!$
!$  implicit none
!$
!$  REAL*8, INTENT(in) :: b,c
!$
!$  if(b.gt.c) then                      ! SORTS b,c IN DECREASING ORDER
!$     compar = -1
!$  elseif(b.lt.c) then
!$     compar = 1
!$  else
!$     compar = 0
!$  endif
!$  return
!$end function compar
