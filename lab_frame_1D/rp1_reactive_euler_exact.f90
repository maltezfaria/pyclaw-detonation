! NOTE from LMF: Attempt to convert exact rp1_reactive_euler_exact.f to Fortran90 code
! ===============================================================================
 subroutine rp1(maxmx,meqn,mwaves,maux,mbc,mx,ql,qr,auxl,wave,s,amdq,apdq)
! ================================================================================
!
!
! on input  : ql contains the data along a 1-d slice
! on output : wave contains the waves, s the speeds, f0 the Godunov
! flux, and amdq, apdq the decomposition of f(i)-f(i-1) into leftgoing
! and rightgoing parts respectively.
!
! INPUT : ql contains the state vector at the left edge of each cell
!         qr contains the state vector at the right edge of each cell
!
! OUTPUT : wave contains the components of the waves
!          s the speeds
!          amdq the left-going flux difference A^-\Delta q
!          apdq the right-going flux difference A^+\Delta q
!
! Note that the i'th Riemann problem has left state qr(i-1,:)

!                                    has right state ql(i,:)
!
! this subroutine is called from step1 with ql=qr=q
!
    implicit double precision (a-h,o-z)
    dimension   ql(meqn,1-mbc:maxmx+mbc)
    dimension   qr(meqn,1-mbc:maxmx+mbc)
    dimension    s(mwaves,1-mbc:maxmx+mbc)
    dimension wave(meqn, mwaves,1-mbc:maxmx+mbc)
    dimension amdq(meqn,1-mbc:maxmx+mbc)
    dimension apdq(meqn,1-mbc:maxmx+mbc)

!     # local storage
!     ---------------
    integer iter,maxit,max2
    double precision ul,ur,um,cl,cr,rhol,rhoml,rhomr,rhor
    double precision zl,zr,pl,pr,pm,po,p,eml,emr
    parameter (max2 = 5004)
    parameter (maxit = 100)
    dimension sl(2),sr(2)
    dimension qstar(meqn),fluxl(meqn),fluxr(meqn),fluxstar(meqn)
    logical efix

    common /cparam/  gamma,gamma1,qheat,bet,tau,tol
!
    data efix /.false./    !# use entropy fix for transonic rarefactions

    do 200 i = 2-mbc, mx+mbc
         rhol=qr(1,i-1)
         rhor=ql(1,i)
         ul=qr(2,i-1)/rhol
         ur=ql(2,i)/rhor
         zl = qr(4,i-1)/qr(1,i-1)
         zr = ql(4,i)/ql(1,i)
         pl = (gamma-1.)*(qr(3,i-1)-0.5d0*qr(2,i-1)*ul &
                       -qheat*zl*rhol)
         pr = (gamma-1.)*(ql(3,i)-0.5d0*ql(2,i)*ur &
                       -qheat*zr*rhor)

         cl=dsqrt(gamma*pl/rhol)
         cr=dsqrt(gamma*pr/rhor)

         do mw = 1, mwaves
           do m=1, meqn
             wave(m,mw,i) = 0.d0
           enddo
           s(mw,i) = 0.d0
         enddo
         y = ur-ul - (2.d0/(gamma-1.))*(cr+cl)
!
!     =========================================================
!     Determination of the structure of the Riemann solution
!     =========================================================
!
         if(ul.le.ur) then
            if(pl.le.pr) then
                iwave3 = 2          !# 3-rarefaction wave
                if(Rl(pl,ur,pr,cr,3).lt.ul) then
                    iwave1 = 1      !# 1-shock
                else
                    iwave1 = 2      !# 1-rarefaction wave
                endif
            else
                iwave1 = 2          !# 1-rarefaction wave
                if(Rl(pr,ul,pl,cl,1).gt.ur) then
                    iwave3 = 1      !# 3-shock
                else
                    iwave3 = 2      !# 3-rarefaction wave
                endif
            endif
         endif


         if(ul.gt.ur) then
            if(pr.le.pl) then
                iwave3 = 1          !# 3-shock
                if(Shl(pl,ur,pr,cr,3).lt.ul) then
                    iwave1 = 1      !# 1-shock
                else
                    iwave1 = 2      !# 1-rarefaction wave
                endif
            else
                iwave1 = 1          !# 1-shock
                if(Shl(pr,ul,pl,cl,1).le.ur) then
                    iwave3 = 2      !# 3-rarefaction wave
                 else
                    iwave3 = 1      !# 3-shock
                endif
            endif
         endif
!
         if(iwave1*iwave3.eq.0) then
            write(6,*) "unable to get the solution structure"
            stop
         endif

         if(iwave1.eq.2 .and. iwave3.eq.2) then
!        two rarefaction waves *
           po=((((gamma-1.)/2.)*(ul-ur)+cl+cr) &
              /( cr/pr**tau+cl/pl**tau ) )**(1./tau)
           pm=po
           um = Rl(pm,ul,pl,cl,1)
           goto 100
         endif
!
!USE NEWTON ITERATION *
         if((iwave1.eq.1) .and. (iwave3.eq.2)) then
!      1-wave is a shock and 3-wave is a rarefaction  *
           iter=0
           p=0.d0
           po = 0.5d0*(pl+pr)
           do 700 j=1,maxit
             p=po-(Shl(po,ul,pl,cl,1)-Rl(po,ur,pr,cr,3))/ &
                    (dS(po,ul,pl,cl,1)-dR(po,ur,pr,cr,3))
             if (dabs(p-po).le.tol) goto 600
                iter=iter+1
                po=p
                if (iter.eq.maxit) then
                   print*,'NEWTON ITERATION EXCEEDED MAXIT'
                   stop
                endif
  700           continue
  600           pm=p
                um = Rl(pm,ur,pr,cr,3)
                goto 100
             endif
!
             if((iwave1.eq.2) .and. (iwave3.eq.1))  then
!          1-wave is a rarefaction and 3-wave is a shock  *
                iter=0
                po = 0.5d0*(pl+pr)
                do 710 j=1,maxit
                   p=po-(Rl(po,ul,pl,cl,1)-Shl(po,ur,pr,cr,3))/ &
                       (dR(po,ul,pl,cl,1)-dS(po,ur,pr,cr,3))
                   if (dabs(p-po).le.tol) goto 610
                   iter=iter+1
                   po=p
                   if (iter.eq.maxit) then
                      print*,'NEWTON ITERATION EXCEEDED MAXIT'
                      stop
                   endif
  710           continue
  610           pm=p
                um = Rl(pm,ul,pl,cl,1)
             goto 100
         endif
!
         if((iwave1.eq.1) .and. (iwave3.eq.1)) then
!      1-wave is a shock and 3-wave is a shock  *
            iter=0
            po = 2.d0*dmax1(pl,pr)
            do 720 j=1,maxit
                p=po-(Shl(po,ul,pl,cl,1)-Shl(po,ur,pr,cr,3))/ &
                    (dS(po,ul,pl,cl,1)-dS(po,ur,pr,cr,3))

                if (dabs(p-po).le.tol) goto 620
                iter=iter+1
                po=p
                if (iter.eq.maxit) then
                   print*,'NEWTON ITERATION EXCEEDED MAXIT'
                   stop
                endif
  720       continue
  620       pm = p
            um = Shl(pm,ul,pl,cl,1)
            goto 100
         endif
  100    continue
!
!Information for Left wave !
!
         if (iwave1.eq.1) then
!      one-wave is a shock
           sl(1) = ul - cl*sqrt(tau*(pl+bet*pm)/pl)
           sr(1) = sl(1)
           rhoml = rhol*((pl+bet*pm)/(pm+bet*pl))
         else
!      one-wave is a rarefaction
           rhoml = rhol*((pm/pl)**(1.d0/gamma))
           cl = sqrt(gamma*pl/rhol)
           cml = cl + 0.5d0*(gamma-1.)*(ul-um)
           sl(1) = ul-cl
           sr(1) = um-cml
         endif


!
!Information for right wave *
!
         if (iwave3.eq.1) then
!      three-wave is a shock
           sl(2) = ur + cr*dsqrt(tau*(pr+bet*pm)/pr)
           sr(2) = sl(2)
           rhomr = rhor*((pr+bet*pm)/(pm+bet*pr))
         else
!      three-wave is a rarefaction
           rhomr = rhor*((pm/pr)**(1./gamma))
           cmr = cr + 0.5d0*(gamma-1.)*(um-ur)
           sl(2) = um+cmr
           sr(2) = ur+cr
         endif
!
!Now compute waves, and speeds s
!
!      ONE WAVE
!
         wave(1,1,i) = rhoml - qr(1,i-1)
         wave(2,1,i) = (rhoml*um) - qr(2,i-1)

         eml = pm/(gamma-1.0d0) + 0.5d0*rhoml*(um**2) &
                            + qheat*rhoml*qr(4,i-1)
         wave(3,1,i) = eml - qr(3,i-1)
         wave(4,1,i) = 0.d0

         s(1,i) = 0.5d0*(sl(1)+sr(1))
!
!      TWO WAVE (Contact Discontinuity)
!
!      # u and p are constant along the 2-contact discontinuity
!
         wave(1,2,i) = rhomr - rhoml
         wave(2,2,i) = rhomr*um - rhoml*um
         wave(3,2,i) = 0.5d0*(rhomr-rhoml)*(um**2) &
                      +qheat*(rhomr*ql(4,i)-rhoml*qr(4,i-1))
         wave(4,2,i) = ql(4,i) - qr(4,i-1)
         s(2,i) = um

!      THREE WAVE
!
         wave(1,3,i) = ql(1,i) - rhomr
         wave(2,3,i) = ql(2,i) - rhomr*um
         emr = pm/(gamma-1.0d0) + 0.5d0*rhomr*(um**2) &
             + qheat*rhomr*ql(4,i)
         wave(3,3,i) = ql(3,i) - emr
         wave(4,3,i) = 0.d0

         s(3,i) = 0.5d0*(sl(2)+sr(2))

  200  continue
       do i=2-mbc, mx+mbc
         do m=1, meqn
           amdq(m,i) = 0.d0
           apdq(m,i) = 0.d0
         enddo
       enddo
       if (efix) go to 110
!
!    compute the leftgoing and rightgoing flux differences
!
        do i=2-mbc, mx+mbc
          pl = (gamma-1.)*(qr(3,i-1)-0.5d0*qr(2,i-1)**2.d0/qr(1,i-1) &
               - qheat*qr(4,i-1)*qr(1,i-1))
          pr = (gamma-1.)*(ql(3,i)-0.5d0*ql(2,i)**2.d0/ql(1,i) &
               - qheat*ql(4,i)*ql(1,i))
          fluxl(1) = qr(2,i-1)
          fluxl(2) = qr(2,i-1)**2.d0/qr(1,i-1)+pl
          fluxl(3) = qr(2,i-1)*(qr(3,i-1)+pl)/qr(1,i-1)
          fluxl(4) = qr(1,i-1)*qr(4,i-1)
          fluxr(1) = ql(2,i)
          fluxr(2) = ql(2,i)**2.d0/ql(1,i)+pr
          fluxr(3) = ql(2,i)*(ql(3,i)+pr)/ql(1,i)
          fluxr(4) = ql(1,i)*ql(4,i)
          do m=1, meqn
            amdq(m,i) = 0.d0
            apdq(m,i) = 0.d0
            qstar(m) = qr(m,i-1)
          enddo
          do mw=1, mwaves
            if(s(mw,i).lt.0.d0) then
              do m=1, meqn
                qstar(m) = qstar(m)+wave(m,mw,i)
              enddo
            endif
          enddo
          pstar = (gamma-1.)*(qstar(3)-0.5d0*qstar(2)**2.d0/qstar(1))
          fluxstar(1) = qstar(2)
          fluxstar(2) = qstar(2)**2.d0/qstar(1)+pstar
          fluxstar(3) = qstar(2)*(qstar(3)+pstar)/qstar(1)
          fluxstar(4) = qstar(1)*qstar(4)
          do m=1, meqn
            amdq(m,i) = fluxstar(m)-fluxl(m)
            apdq(m,i) = fluxr(m)-fluxstar(m)
          enddo
        enddo
        go to 900

  110   continue

!
!    # With entropy fix
!    ------------------
!
!   # compute flux differences amdq and apdq.
!   # First compute amdq as sum of s*wave for left going waves.
!   # Incorporate entropy fix by adding a modified fraction of wave
!   # if s should change sign.
!
      do i=2-mbc,mx+mbc
!
!       # check 1-wave:
!       ---------------
!
	 rhoim1 = qr(1,i-1)
	 pim1 = (gamma-1.d0)*(qr(3,i-1) - 0.5d0*qr(2,i-1)**2 / rhoim1 &
                           -qheat*rhoim1*qr(4,i-1))
	 cim1 = dsqrt(gamma*pim1/rhoim1)
	 s0 = qr(2,i-1)/rhoim1 - cim1     !# u-c in left state (cell i-1)

!        # check for fully supersonic case:
	 if (s0.ge.0.d0 .and. s(1,1).ge.0.d0)  then
!           # everything is right-going
	     do  m=1,meqn
		amdq(m,i) = 0.d0
             enddo
	     go to 300
	 endif
!
         rho1 = qr(1,i-1) + wave(1,1,i)
         rhou1 = qr(2,i-1) + wave(2,1,i)
         en1 = qr(3,i-1) + wave(3,1,i)
         z1 = qr(4,i-1) + wave(4,1,i)
         p1 = (gamma-1.d0)*(en1 - 0.5d0*rhou1**2/rho1-qheat*rho1*z1)
         c1 = dsqrt(gamma*p1/rho1)
         s1 = rhou1/rho1 - c1  !# u-c to right of 1-wave
         if (s0.lt.0.d0 .and. s1.gt.0.d0) then
!             write(6,*), "transonic rarefaction in the 1-wave"
!            # transonic rarefaction in the 1-wave
	     sfract = s0 * (s1-s(1,i)) / (s1-s0)
	   else if (s(1,i) .lt. 0.d0) then
!	     # 1-wave is leftgoing
	     sfract = s(1,i)
	   else
!	     # 1-wave is rightgoing
             sfract = 0.d0   !# this shouldn't happen since s0 < 0
	   endif
	 do 120 m=1,meqn
	    amdq(m,i) = sfract*wave(m,1,i)
  120       continue
!
!        # check 2-wave:
!        ---------------
!
         if (s(i,2) .ge. 0.d0) go to 300  !# 2-wave is rightgoing
	 do 140 m=1,meqn
	    amdq(i,m) = amdq(i,m) + s(i,2)*wave(i,m,2)
  140       continue
!
!        # check 3-wave:
!        ---------------
!
         rhoi = ql(i,1)
         pi = (gamma-1.d0)*(ql(i,3)-0.5d0*ql(i,2)**2/rhoi &
               -qheat*rhoi*ql(i,4))
         ci = dsqrt(gamma*pi/rhoi)
         s3 = ql(i,2)/rhoi + ci     !# u+c in right state  (cell i)
!
         rho2 = ql(i,1) - wave(i,1,3)
         rhou2 = ql(i,2) - wave(i,2,3)
         en2 = ql(i,3) - wave(i,3,3)
         z2 = ql(i,4) - wave(i,4,3)
         p2 = (gamma-1.d0)*(en2-0.5d0*rhou2**2/rho2-qheat*rho2*z2)
         c2 = dsqrt(gamma*p2/rho2)
         s2 = rhou2/rho2+c2   !# u+c to left of 3-wave
         if (s2 .lt. 0.d0 .and. s3.gt.0.d0) then

!            # transonic rarefaction in the 3-wave
	     sfract = s2 * (s3-s(i,3)) / (s3-s2)
	   else if (s(i,3) .lt. 0.d0) then
!            # 3-wave is leftgoing
       	     sfract = s(i,3)
	   else if(s(i,3).gt.0.d0) then
!            # 3-wave is rightgoing
       	     go to 300
	   endif
!
	 do 160 m=1,meqn
	    amdq(m,i) = amdq(m,i) + sfract*wave(m,3,i)
  160       continue
  300    continue
         enddo
!
!     # compute the rightgoing flux differences:
!     # df = SUM s*wave   is the total flux difference and apdq = df - amdq
!
      do 220 m=1,meqn
	 do 220 i = 2-mbc, mx+mbc
	    df = 0.d0
	    do 210 mw=1,mwaves
	       df = df + s(mw,i)*wave(m,mw,i)
  210          continue
	    apdq(m,i) = df - amdq(m,i)
  220       continue
!

  900   continue
        RETURN
        END
!--------------------------------------------------------------------!
!BEGIN FUNCTION DEFINITIONS !
!--------------------------------------------------------------------!
       double precision function Rl(p,uk,pk,ck,m)
       implicit double precision (a-h,o-z)
       integer m
       common /cparam/  gamma,gamma1,qheat,bet,tau,tol
       If (m.eq.1) then
!     function called with uk=ul, pk=pl, etc...
        Rl = uk + (2./(gamma-1.))*ck*(1.-(p/pk)**tau)
       else if (m.eq.3) then
!     function called with uk=ur, etc...
        Rl = uk - (2./(gamma-1.))*ck*(1.-(p/pk)**tau)
       end if
       return
       end
!--------------------------------------------------------------------!
       double precision function Shl(p,uk,pk,ck,m)
       implicit double precision (a-h,o-z)
       integer m
       common /cparam/  gamma,gamma1,qheat,bet,tau,tol
       If (m.eq.1) then
!     function called with uk=ul, etc...
        Shl=uk+((2.*dsqrt(tau))/(gamma-1.))*ck &
                 *((pk-p)/dsqrt(pk*(pk+p*bet)))
       else if (m.eq.3) then
!     function called with uk=ur, etc ...
        Shl=uk-((2.*dsqrt(tau))/(gamma-1.))*ck*((pk-p)/dsqrt(pk*(pk+bet* &
          p)))
       end if
       return
       end
!--------------------------------------------------------------------!
       double precision function dR(p,uk,pk,ck,m)
       implicit double precision (a-h,o-z)
       integer m
       common /cparam/  gamma,gamma1,qheat,bet,tau,tol
       If (m.eq.1) then
        dR = (-2.d0*tau*ck/(gamma-1.d0)) &
               *(p**(tau-1.))/(pk)**tau
       else if (m.eq.3) then
        dR = (2.*tau*ck/(gamma-1.))*(p**(tau-1.))/(pk)**tau
       end if

       return
       end
!--------------------------------------------------------------------!
       double precision function dS(p,uk,pk,ck,m)
       implicit double precision (a-h,o-z)
       integer m
       common /cparam/  gamma,gamma1,qheat,bet,tau,tol
       If (m.eq.1) then
        dS = (-2.d0*dsqrt(tau)*ck/(gamma-1.d0))*((pk**2)*(1.d0+0.5d0*bet) &
            +0.5d0*pk*bet*p)/(pk*(pk+bet*p))**1.5
       else if (m.eq.3) then

        dS = (2.*dsqrt(tau)*ck/(gamma-1.))*(pk**2*(1+.5*bet)+.5*pk*bet* &
           p)/(pk*(pk+bet*p))**1.5
       end if
       return
       end
