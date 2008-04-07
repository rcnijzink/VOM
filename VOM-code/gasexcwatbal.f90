!********************************************************************
!*		Transpiration model and layered water balance
!*--------------------------------------------------------------------
!*		Author: Stan Schymanski, CWR, University of Western Australia
!*		03/2006
!*  now at: Max Planck Institute for Biogeochemistry
!*  Email: sschym@bgc-jena.mpg.de
!*  02/2008
!*		Version: big leaf, trees and grass, layered unsaturated zone
!*		optimised root profile, pcg and Jmax225
!*--------------------------------------------------------------------
!*
!*	Numbers in the commented parentheses refer to the equation numeration
!*	in Schymanski (2007): PhD thesis, University of W.A. 
!*  and in the document 'equations.pdf' that comes with the documentation.
!*
!*--------------------------------------------------------------------
!*  Copyright (C) 2008  Stan Schymanski
!*
!*    This program is free software: you can redistribute it and/or modify
!*    it under the terms of the GNU General Public License as published by
!*    the Free Software Foundation, either version 3 of the License, or
!*    (at your option) any later version.
!*
!*    This program is distributed in the hope that it will be useful,
!*    but WITHOUT ANY WARRANTY; without even the implied warranty of
!*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!*    GNU General Public License for more details.
!*
!*    You should have received a copy of the GNU General Public License
!*    along with this program.  If not, see <http://www.gnu.org/licenses/>.
!*
!********************************************************************
!
subroutine transpmodel(invar,nrun,netass,option1)

implicit none

INTEGER(1) option1
CHARACTER(60) dailyformat,hourlyformat
CHARACTER(3) str
!*
!*=====<Parameters>===================================================
!* set O2 conc [mol/mol], CO2 conc and diffusion conversion factor from
!* CO2 to H2O as parameters. 
!  
REAL*8 a,pi,E,r,g,rho,degree,mpbar
REAL*8, SAVE :: oa,ca,alpha,rlratio,k25,kopt,ha,hd,topt,&
						cpccf,tcf									! cpccf=water transport costs per m root depth and m^2 cover; 
INTEGER, SAVE :: parsaved,ny,nyt,firstyear,lastyear
PARAMETER(a=1.6d0,pi=3.14159d0,mpbar=10.2d0,&						! mpbar=conversion factor from MPa to bar
					g=9.81d0,rho=1000.d0,degree=0.0174533d0)			
PARAMETER(E=2.7182818d0,R=8.314d0)
INTEGER, SAVE :: N,Nh,M,optmode
INTEGER nrun,d,h,oldh,i,in,ii,ik,yr,dtest,pos,posg,postemp,pos1(1),&
			pos2(2),stat,dummyint1,dummyint2,dummyint3,dummyint4
REAL*8, ALLOCATABLE, SAVE :: srad(:),rhmax(:),rhmin(:),tmin(:),&
			tmax(:),rainvec(:),netassvec(:),epan(:),vpvec(:),&
			netassvecg(:)
INTEGER, ALLOCATABLE, SAVE :: year(:),month(:),day(:),dayyear(:)
REAL*8, ALLOCATABLE, SAVE :: avparvec(:),&
			parvec(:),parh(:),vdh(:),tairh(:),gammastarvec(:),rainh(:)
REAL*8 jact(3),lambda,gstom,rl(3),vd,par,rain,transp,&
			ass(3),hass(3),pc,cpcc,sunr,suns,rr,&				
			lambdafac,gammastar,jmax(3),jmax25(3),&
			netassyr,rainyr,epanyr,paryr,radyr,vdyr,etyr,evapyr,&
			gppyr,daylength,tamean,dtr,tair,vp,&
			rootdepth,mq,mqssmin,time,dmq,mqnew,mqss,changef,&
			mqold,hruptk,error1,tc,mqssnew,pcg(3),lambdagfac,wsgexp,&
			cpccg(3),tcg(3),jmax25g(3),wsexp,rgdepth,&
			lambdag,rrg,jmaxg(3),rlg(3,3),jactg(3,3),gstomg(3,3),&
			etmg(3,3),transpg(3,3),assg(3,3),hassg(3,3),hetmg,&
			assg_d(3,3),jmaxg_d,gstomg_d,etmg_d,rlg_d,netassg_d(3,3),rootlim(3,3)
REAL*8, SAVE :: md,mqx,rcond,rsurfmin,rsurfinit,rootrad,	&
			rrootm,pcgmin,prootmg,mdf,mqxf,mdstore,growthmax
REAL*8 ruptk_d,	jmax_d,rl_d,gstom_d,ass_d(3),spgfcf_d,infx_d,etm_d,&
			esoil_d,vd_d
REAL*8, INTENT(inout) :: netass
REAL*8,  INTENT(in) :: invar(10)
CHARACTER(100) :: informat
!*********************************************************************
!*     Parameters for Water balance model
!*********************************************************************
!
INTEGER nlayers,nlayersnew
REAL*8, SAVE :: dt,cz,cgs,lat								! lat=geogr. latitude
REAL*8, SAVE :: ksat,epsln,nvg,mvg,alphavg,zs,zr,go,thetas,&
			thetar,wsold,delyu,ets
REAL*8, ALLOCATABLE, SAVE :: pcapvec(:),suvec(:),ruptkvec(:),&
			sunewvec(:),wsvec(:),kunsatvec(:),delyuvec(:),rsurfvec(:),&
			rsurfnewvec(:),qblvec(:),dsuvec(:),phydrostaticvec(:),&
			delyunewvec(:),wsnewvec(:),prootmvec(:),pcapnewvec(:),&
			hruptkvec(:),ruptkvec_d(:),reff(:),ruptkg(:),rsurfg(:),&
			rsurfgnew(:),rsoilvec(:)
REAL*8 ys,yu,omgu,omgo,depth,etm,esoil,esoils,dys,dtys,&
			domgu,dtsu,ysnew,yunew,wsnew,io,iocum,spgfcf,hspgfcf,infx,&
			hinfx,hio,hesoil,hetm,inf,dyu,omgunew,&
			omgonew,error,dtmq,hinf,dtss
!*********************************************************************
!*     Program options
!*********************************************************************
!
if (option1.eq.2) then
	optmode=0
else
	optmode=1
endif
ets=0.d0														! we assume that no water uptake in the saturated zone is happening
!*--------------------------------------------------------------------
!*
!*    PARAMETER READING FROM INPUT.PAR
!*
!*--------------------------------------------------------------------
!
if (parsaved.ne.1) then
	open(201,file='input.par',status='old')
	read(201,*) oa
	read(201,*) ca
	read(201,*) alpha
	read(201,*) cpccf	
	read(201,*) tcf
	read(201,*) ny
	read(201,*) nyt
	read(201,*) k25
	read(201,*) kopt	
	read(201,*) ha
	read(201,*) hd
	read(201,*) topt
	read(201,*) rlratio
!*-----Catchment parameters --------------------------------------------
!
	read(201,*) lat
	read(201,*) cz
	read(201,*) zs
	read(201,*) cgs	
	read(201,*) zr
	read(201,*) go
!*-----Soil parameters --------------------------------------------
!
	read(201,*) ksat	
	read(201,*) thetar
	read(201,*) thetas
	read(201,*) nvg
	read(201,*) alphavg
	epsln=thetas-thetar											! epsilon, porosity see Reggiani (2000)
	mvg=1-(1/nvg)												! van Genuchten soil parameter m
!*-----Vertical Resolution--- -------------------------------------
!
	read(201,*) delyu
!*-----Vegetation Parameters--- -------------------------------------
	read(201,*) mdf
	read(201,*) mqxf
	read(201,*) rrootm
	read(201,*) rsurfmin
	read(201,*) rsurfinit
	read(201,*) rootrad
	read(201,*) prootmg
	read(201,*) growthmax
	read(201,*) firstyear
	read(201,*) lastyear
	rcond=1./rrootm												! root conductivity in s^-1 (ruptk=rcond(proot-psoil)rsurf
	close(201)
!*	
!*	End of Runoff model initialisation
!*********************************************************************
!*-----calculate vector sizes-----------------------------------------
!
	N=ceiling(ny*365.25)
	Nh=N*24
	M=ceiling(cz/delyu)											! maximum number of soil sublayers
!*
!*-----allocate vector sizes------------------------------------------
!
	allocate(srad(N),rhmax(N),rhmin(N),tmin(N),tmax(N),rainvec(N))
	allocate(year(N),month(N),day(N),dayyear(N),vpvec(N),epan(N))
	allocate(avparvec(N))
	allocate(parvec(N))
	allocate(netassvec(N),netassvecg(N))
	allocate(parh(Nh),vdh(Nh),tairh(Nh),gammastarvec(Nh),rainh(Nh))
	allocate(pcapvec(M),suvec(M),ruptkvec(M),sunewvec(M),wsvec(M),&
			kunsatvec(M),delyuvec(M),rsurfvec(M),rsurfnewvec(M),&
			qblvec(M),dsuvec(M),phydrostaticvec(M),delyunewvec(M),&
			wsnewvec(M),prootmvec(M),pcapnewvec(M),ruptkvec_d(M),&
			hruptkvec(M),reff(M),ruptkg(M),rsurfg(M),rsurfgnew(M),&
			rsoilvec(M))
!*--------------------------------------------------------------------
!*
!*     File opening
!*
!*--------------------------------------------------------------------
!-----saving climate and gstom ass data ------------------------------
!
	if (optmode.eq.0) then
		open(201,file='resultshourly.txt')
		close(201,status='delete')
		open(201,file='resultshourly.txt')
		write(201,101)'year','month','day','dcum','hour','rain','tair',&
   			'par','vd','esoil','pc','jmax25_t','jmax25_g','mq','rl'&
   			,'lambda_t','lambda_g','rr','ass_t','ass_g','het_t','het_g',&
			'su_1','ys','Ws','omgo','spgfcf','infx'

		open(202,file='resultsdaily.txt')
		close(202,status='delete')
		open(202,file='resultsdaily.txt')
		write(202,101)'year','month','day','dcum','hour','rain','tmax',&
   			'tmin','par','vd','esoil','jmax25_t','jmax25_g','pc','rlt+rlg'&
   			,'lambda_t','lambda_g','rr_t','rr_g','ass_t','ass_g','su_avg',&
   			'ys','ws','spgfcf','infx','etm_t','etm_g','su_1'

		open(203,file='yearly.txt')
		close(203,status='delete')
		open(203,file='yearly.txt')
		write(203,'(a6,9a15)') "year","rainyr","epanyr","paryr","radyr","vdyr","etyr",&
			"esoilyr","netassyr","gppyr"

		open(204,file='rsurfdaily.txt')
		close(204,status='delete')
		open(204,file='rsurfdaily.txt')
		write(204,*)' year',' month',' day','   dcum','  rsurfsublayer'

		open(205,file='delyudaily.txt')
		close(205,status='delete')
		open(205,file='delyudaily.txt')
		write(205,*)' year',' month',' day','   dcum',' hour','  delyusublayer'

		open(206,file='ruptkhourly.txt')
		close(206,status='delete')
		open(206,file='ruptkhourly.txt')
		write(206,*)' year',' month',' day','   dcum',' hour','  delyusublayer'

		open(207,file='suvechourly.txt')
		close(207,status='delete')
		open(207,file='suvechourly.txt')
		write(207,*)' year',' month',' day','   dcum',' hour','  susublayer'
	endif														! only creates file if not in 'optimise' mode
!*
!*--------------------------------------------------------------------
!*     Climate and Calendar data reading
!*--------------------------------------------------------------------
!----Reading hourly climate data if available-------------------------
!
	open(102,file='hourlyweather.prn',status='old',iostat=stat) 
	if (stat.ne.0) then
		close(102)
!----Creating hourly climate data from daily data---------------------		
!
		informat='(4i8,6f8.2)'
		open(101,file='dailyweather.prn',status='old',iostat=stat) 
		read(101,*)
		read(101,*)
		do i=1,N
			read(101,informat) dayyear(i),day(i),month(i),year(i),tmax(i),&
					tmin(i),rainvec(i),epan(i),srad(i),vpvec(i)
		enddo		    			
		close(101)
		open(102,file='hourlyweather.prn',iostat=stat)
		write(102,'(5a8,4a10)') '   hour',' dayyear','     day','   month','    year',&
			'      tair','        vd','      parh','     rainh'
!*********************************************************************
!*		Calculation of vegetation parameters
!*     
!*--------------------------------------------------------------------
!*		Equations in Fortrform16.nb.pdf
!*		(numeration in the commented parentheses)
!*********************************************************************
!*--------------------------------------------------------------------
!*
!*	Calculation of derived parameters
!*
!*--------------------------------------------------------------------
!			
		parvec=2.0804d0*srad														! (Out[17]), par in mol/m2 if srad was MJ/m2
		do in=1,N
			daylength=12.d0 - 7.639437d0*ASin((0.397949d0*Cos(0.172142d0 + &		! (Out[22]), in hours
				0.017214d0*dayyear(in))*Tan(0.017453d0*lat))/&
				Sqrt(0.920818d0 - 0.079182d0*Cos(0.344284d0 + 0.034428d0*&
				dayyear(in))))
			sunr=12d0-0.5d0*daylength							! sets time of sunrise and sunset
			suns=12d0+0.5d0*daylength	
			tamean=(tmax(in)+tmin(in))/2.d0
			dtr=tmax(in)-tmin(in)
			vp=vpvec(in)*100.d0									! vp in Pa
			do ik=1,24											! Loop through every hour of day, where ik=hour
				ii=in*24+ik-24
				tair=tamean + dtr*(0.0138d0*Cos(3.513d0 - ((-1.d0 + ik)*Pi)/&		! (Out[38], accounts for diurnal variation in air temperature
					3.d0) + 0.0168d0*Cos(0.822d0 - ((-1.d0 + ik)*Pi)/4.d0) + &		! (derived from 3.52+3.53) 
					0.0984d0*Cos(0.36d0 - ((-1.d0 + ik)*Pi)/6.d0) + &
					0.4632d0*Cos(3.805d0 - ((-1.d0 + ik)*Pi)/12.d0))
				tairh(ii)=tair
				vd=0.006028127d0*2.718282d0**((17.27d0*tair)/(237.3d0 +&			! (Out[52]), accounts for diurnal variation in vapour deficit
					tair)) - 9.869233d-6*vp											! (derived from 3.54+3.55) 
				if(vd.le.0.d0)then
					vd=0.d0
				endif
				gammastarvec(ii)=0.00004275d0*E ** ((18915.d0*(-25.d0 + tair))/&	! (Out[274], derived from (3.25))
					(149.d0*R*(273.d0 + tair)))
				vdh(ii)=vd
				rainh(ii)=rainvec(in)/(24.d0*3600.d0*1000.d0)						! average rainfall in hour ii (m/s)
				if (sunr.le.ik .and. ik+1.le.suns) then
					parh(ii)=(-0.000873d0*parvec(in)*Cos(0.017453d0*lat)*&			! ([Out30]), in mol/m2/s
						Sqrt(0.920818d0 - 0.079182d0*Cos(0.034428d0*&				! (derived from 3.51) accounts for diurnal variation in global irradiance
						(10.d0 + dayyear(in))))*Cos(0.2618d0*ik) - 0.000347d0*&
						parvec(in)*Cos(0.017214d0*&
						(10.d0 + dayyear(in)))*Sin(0.017453d0*lat))/&
						(-1.250192d0*daylength*Cos(0.017214d0*(10.d0 +&
						dayyear(in)))*Sin(0.017453d0*lat) + 24.d0*&
						Cos(0.017453d0*lat)*Sqrt(0.920818d0 - 0.079182d0*&
						Cos(0.034428d0*(10.d0 + dayyear(in))))*&
						(1.d0 - (0.158363d0*Cos(0.017214d0*(10.d0 + dayyear(in)))**2.d0*&
						Tan(0.017453d0*lat)**2.d0)/(0.920818d0 - 0.079182d0*&
						Cos(0.034428d0*(10.d0 + dayyear(in)))))**0.5d0)
				else 
					parh(ii)=0.d0
				endif
				write(102,'(5i8,4e10.3)') ik,dayyear(in),day(in),month(in),year(in),&
					tairh(ii),vdh(ii),parh(ii),rainh(ii)
				gammastarvec(ii)=0.00004275d0*E ** ((18915.d0*(-25.d0 + tairh(ii)))/&	! (Out[274], derived from (3.25))
					(149.d0*R*(273.d0 + tairh(ii))))
			enddo
		enddo
		close(102)
		open(102,file='hourlyweather.prn',status='old',iostat=stat) 
	endif
	read(102,*) 
	ii=1
	oldh=99
	do i=1,Nh
		read(102,'(5i8,4e10.3)') h,dummyint1,dummyint2,dummyint3,dummyint4,&
			tairh(i),vdh(i),parh(i),rainh(i)
		if(h.lt.oldh) then
			dayyear(ii)=dummyint1
			day(ii)=dummyint2
			month(ii)=dummyint3
			year(ii)=dummyint4
			ii=ii+1
		endif
		oldh=h
		gammastarvec(i)=0.00004275d0*E ** ((18915.d0*(-25.d0 + tairh(i)))/&				! (Out[274], derived from (3.25)) 
			 (149.d0*R*(273.d0 + tairh(i))))
	enddo
	close(102)
	parsaved=1	
endif
!*--------------------------------------------------------------------
!*
!*     Initial values 
!*
!*--------------------------------------------------------------------
!
NETASS=0.d0
!*--------------------------------------------------------------------
!*
!*     Set soil moisture and vegetation parameters to initial conditions 
!*
!*--------------------------------------------------------------------
!	
ysnew=zr														! catchment filled up to channel bottom
omgunew=1.d0														! (3.1)
omgonew=1.d0-omgunew
yunew=(cz - ysnew)/omgunew										! (3.2)
nlayersnew=Floor(yunew/delyu)									! (3.3)
delyunewvec(:)=delyu
delyunewvec(nlayersnew)=yunew - (nlayersnew - 1.d0)*delyu
depth=ysnew+delyunewvec(nlayersnew)/2.d0
sunewvec(nlayersnew)=(1.d0 + (alphavg*(depth - ysnew))**nvg)**(-mvg)	! (Out[58])
do i=nlayersnew-1,1,-1											
	depth=depth+(delyunewvec(i)+delyunewvec(i+1))/2.d0
	sunewvec(i)=(1.d0 + (alphavg*(depth - ysnew))**nvg)**(-mvg)		! (Out[58])
enddo
sunewvec(nlayersnew+1:M)= 1.d0
wsnewvec(1:nlayersnew)=sunewvec(1:nlayersnew)*epsln*omgunew*&	! (3.18) water content in unsaturated soil layers (m)
	delyunewvec(1:nlayersnew)
wsold=ysnew*epsln + Sum(wsnewvec(1:nlayersnew))					! initial soil water storage
wsnew=wsold
ys=ysnew
omgu=omgunew
omgo=omgonew
yu=yunew
nlayers=nlayersnew
delyuvec=delyunewvec
suvec=sunewvec
wsvec=wsnewvec
pcapvec(1:nlayersnew)= (-1.d0 + sunewvec(1:nlayersnew)**(-1.d0/mvg))**&	! (Out[54])
		(1.d0/nvg)/alphavg
pcapvec(nlayersnew+1:M)=0.d0
write(str,'(i3)') nlayers										! internal write to convert from number to string
dailyformat='(i6,i6,i4,i7,'//str//'e14.6)'						! includes a column for each sublayer 
hourlyformat='(i6,i6,i4,i7,i5,'//str//'e14.6)'					! includes a column for each sublayer
!*--------------------------------------------------------------------
!*     Optimised parameters reading from invar
!*--------------------------------------------------------------------
!
lambdagfac=invar(1)
wsgexp=invar(2)	
lambdafac=invar(3)
wsexp=invar(4)
pc=invar(5)
rootdepth=invar(6)
mdstore=invar(7)
rgdepth=invar(8)
if(rootdepth.gt.cz) then
	write(6,*) 'Root depth greater than soil depth'
	rootdepth=cz
endif
!*--------------------------------------------------------------------
!*	Setting yearly, daily and hourly parameters
!*--------------------------------------------------------------------
!
yr=year(1)
netassyr=0.d0	
gppyr=0.d0
rainyr=0.d0
paryr=0.d0
radyr=0.d0
vdyr=0.d0
etyr=0.d0
epanyr=0.d0
evapyr=0.d0
ruptk_d=0.d0
ruptkvec_d=0.d0
vd_d=0.d0
jmax_d=0.d0
gstom_d=0.d0
etm_d=0.d0
esoil_d=0.d0
ass_d=0.d0
assg_d=0.d0
spgfcf_d=0.d0
infx_d=0.d0
rl_d=0.d0
hass=0.d0
hassg=0.d0
hspgfcf=0.d0
hinfx=0.d0
hio=0.d0
hesoil=0.d0
hetm=0.d0
hetmg=0.d0
hruptk=0.d0
hruptkvec=0.d0
hinf=0.d0
netassvec=0.d0
netassvecg=0.d0
iocum=0.d0
!*--------------------------------------------------------------------
!*     Set vegetation parameters 
!*--------------------------------------------------------------------
!
md=pc*mdf+mdstore
mqx=md*mqxf
mqnew=0.95d0*mqx												! initial wood water storage 
mqold=mqnew
rsurfnewvec(:)=0.d0
pos=Ceiling(rootdepth/delyu)
posg=Ceiling(rgdepth/delyu)
rsurfgnew(1:posg)=rsurfinit*omgunew*delyunewvec(1:posg)
rsurfgnew(posg+1:M)=0.d0
if(posg.gt.nlayersnew) then
	rsurfgnew(nlayersnew+1:posg)=rsurfmin*&
		delyunewvec(nlayersnew+1:pos)*omgunew
endif
rsurfnewvec(1:pos)=rsurfinit*delyunewvec(1:pos)*omgunew			! root surface density (root surface area/soil volume) in each sublayer
if(pos.gt.nlayersnew) then
	rsurfnewvec(nlayersnew+1:pos)=rsurfmin*&
		delyunewvec(nlayersnew+1:pos)*omgunew
endif
jmax25(2)=0.0003d0
jmax25g(2)=0.0003d0
pcgmin=0.02d0													! minimum grass pc; initial point for growth
pcg(2)=Min(1.d0-pc,pcgmin)
pcg= pcg(2)+(/-0.02,0.0,0.02/)									! vector with values varying by 1%
pcg(3)=Min(Max(pcgmin,pcg(3)),1.d0-pc)
rootlim=0.d0
!*--------------------------------------------------------------------
!*     Direct costs
!*--------------------------------------------------------------------
!
tc=tcf*pc*2.5d0													! (3.38) 	foliage tunrover costs, assuming crown LAI of 2.5
!*--------------------------------------------------------------------
!*    Daily loops
!*--------------------------------------------------------------------
!
d=0
dtest=nyt*365
902	do while (d.lt.dtest)
		d=d+1
		rsurfvec=rsurfnewvec
		rsurfg=rsurfgnew
		lambda=lambdafac*(Sum(pcapvec(1:pos))/pos)**wsexp		! (3.45) 
		lambdag=lambdagfac*pcapvec(1)**wsgexp					! (3.44) 
		jmax25= jmax25(2)*(/0.99,1.0,1.01/)						! vector with values varying by 1%
		jmax25=Max(jmax25,50.0d-6)								! making sure that the values don't become too low, otherwise they could never pick up again
		jmax25g= jmax25g(2)*(/0.99,1.0,1.01/)
		jmax25g=Max(jmax25g,50.0d-6)
		pcg= pcg(2)+(/-0.02,0.0,0.02/)							! vector with values varying by 1%
		pcg= Max(pcg,0.d0)
		pcg(3)=Min(Max(pcgmin,pcg(3)),1.d0-pc)
		tcg=tcf*pcg*2.5d0										! (3.38) foliage turnover costs, assuming LAI/pc of 2.5
		rr=2.55d-7*Sum(rsurfvec(1:pos))							! (3.40), (Out[190])		root respiration [mol/s]
		if(pos.gt.nlayersnew) then
			cpcc=cpccf*pc*rootdepth+mdstore*2.45d-10			! (3.42, 2.45e-10 from (Out[165])) costs of water distribution and storage		
		else													
			cpcc=cpccf*pc*Sum(delyunewvec(1:pos))+mdstore*2.45d-10
		endif
		if(nlayersnew.lt.posg) then
			cpccg=cpccf*pcg*rgdepth								 ! (3.42) water transport costs
		else
			cpccg=cpccf*pcg*Sum(delyunewvec(1:posg))
		endif
		rrg=2.55d-7*Sum(rsurfg(1:posg))							! (3.40), (Out[190])		root respiration grasses [mol/s] 
		mqssmin=mqx												! resetting the minimum steady-state tissue water content to its maximum value
		if (optmode.eq.0) then									! used for daily recalculation
			tmax(d)=-9999.d0
			tmin(d)=9999.d0
			rainvec(d)=0.d0
			parvec(d)=0.d0
			srad(d)=0.d0
		endif
!*--------------------------------------------------------------------
!*    Hourly loops
!*--------------------------------------------------------------------	
		do h=1,24												! loops through each hour of daily dataset
			ii=d*24+h-24
			rain=rainh(ii)
			gammastar=gammastarvec(ii)
			tair=tairh(ii)
			vd=vdh(ii)
			par=parh(ii)
			jmax=(E**((ha*(-25.d0 + tair)*(-273.d0 + topt + 273.d0*r*topt))/&	! (Out[310], derived from (3.26)) Temperature dependence of Jmax
				((25.d0 + 273.d0*r*topt)*(tair + 273.d0*r*topt)))*&
				((-1.d0 + E**(-(hd*(-298.d0 + topt))/(25.d0 + 273.d0*r*topt)))*ha +& 
				hd)*jmax25)/&
				((-1.d0 + E**((hd*(273.d0 + tair - topt))/(tair + 273.d0*r*topt)))*&
				ha + hd)
			rl=((ca - gammastar)*pc*jmax*rlratio)/&								! (3.24), (Out[312])
				(4.d0*(ca + 2.d0*gammastar)*(1.d0 + rlratio))
			jmaxg=(E**((ha*(-25.d0 + tair)*(-273.d0 + topt + 273.d0*r*topt))/&	! (Out[310], derived from (3.26)) Temperature dependence of Jmax
				((25.d0 + 273.d0*r*topt)*(tair + 273.d0*r*topt)))*&
				((-1.d0 + E**(-(hd*(-298.d0 + topt))/(25.d0 + 273.d0*r*topt)))*ha +& 
				hd)*jmax25g)/&
				((-1.d0 + E**((hd*(273.d0 + tair - topt))/(tair + 273.d0*r*topt)))*&
				ha + hd)
			rlg(1,:)=((ca - gammastar)*pcg(1)*jmaxg*rlratio)/&					! (3.24), (Out[312])
				(4.d0*(ca + 2.d0*gammastar)*(1.d0 + rlratio))
			rlg(2,:)=((ca - gammastar)*pcg(2)*jmaxg*rlratio)/&					! (3.24), (Out[312])
				(4.d0*(ca + 2.d0*gammastar)*(1.d0 + rlratio))
			rlg(3,:)=((ca - gammastar)*pcg(3)*jmaxg*rlratio)/&					! (3.24), (Out[312])
				(4.d0*(ca + 2.d0*gammastar)*(1.d0 + rlratio))
			if (optmode.eq.0) then												! daily recalculation for resultsdaily
				rainvec(d)=rainvec(d)+rain*3600.d0*1000.d0						! mm/d 
				parvec(d)=parvec(d)+par*3600.d0									! in mol/m2/d
				srad(d)=parvec(d)/2.0804d0										! MJ/m2/d
				if(tair.gt.tmax(d)) then	
					tmax(d)=tair
				endif
				if(tair.lt.tmin(d)) then	
					tmin(d)=tair
				endif		
			endif	
!*-----calculate gstom, et and ass --------------------------------------- 
!
			if (par.gt.0.d0)then
				jact=(1.d0 - E**(-(alpha*par)/jmax))*jmax*pc					! (3.23), (Out[311])
				jactg(1,:)=(1.d0 - E**(-(alpha*par)/jmaxg))*jmaxg*pcg(1)		! (3.23), (Out[311]) 
				jactg(2,:)=(1.d0 - E**(-(alpha*par)/jmaxg))*jmaxg*pcg(2)		! (3.23), (Out[311])
				jactg(3,:)=(1.d0 - E**(-(alpha*par)/jmaxg))*jmaxg*pcg(3)		! (3.23), (Out[311])
				if (vd.gt.0.d0.and.lambda.gt.(2.d0*a*vd)/(ca + 2.d0*gammastar)&
						.and.jact(2).gt.(4.d0*ca*rl(2) + 8.d0*gammastar*rl(2))/&
						(ca - gammastar)) then
					gstom=Max(0.d0,(0.25d0*(a*(ca*(jact(2) - 4.d0*rl(2)) - 4.d0*&	! (Out[314]) 
						gammastar*(jact(2) + 2.d0*rl(2)))*vd*(ca*lambda + 2.d0*&
						gammastar*lambda - a*vd) + 1.7320508075688772d0*&
						Sqrt(a*gammastar*jact(2)*(ca*(jact(2) - 4.d0*rl(2)) - &
						gammastar*(jact(2) + 8.d0*rl(2)))*&
						vd*(ca*lambda + 2.d0*gammastar*lambda - 2.d0*a*vd) ** &
						2.d0*(ca*lambda + 2.d0*gammastar*lambda - a*vd))))/&
						(a*(ca +	2.d0*gammastar) ** 2.d0*vd*(ca*lambda + 2.d0*&
						gammastar*lambda - a*vd)))
				else
					gstom=0.d0
				endif
				transp=a*vd*gstom												! (3.28)		transpiration rate in mol/s
				etm=(transp*18.d0)/(10.d0**6.d0)								! transpiration rate in m/s
				where (vd.gt.0.d0.and.lambdag.gt.(2.d0*a*vd)/(ca + 2.d0*gammastar)&
						.and.jactg.gt.(4.d0*ca*rlg + &
						8.d0*gammastar*rlg)/(ca - gammastar)) 
					gstomg=Max(0.d0,(0.25d0*(a*(ca*(jactg-4.d0*rlg)-4.d0*&		! (Out[314]) 
						gammastar*(jactg+2.d0*rlg))*vd*(ca*lambdag+2.d0*&
						gammastar*lambdag - a*vd) + 1.7320508075688772d0*&
						Sqrt(a*gammastar*jactg*(ca*(jactg-4.d0*&
						rlg)-gammastar*(jactg + 8.d0*rlg))*&
						vd*(ca*lambdag + 2.d0*gammastar*lambdag - 2.d0*a*vd) ** &
						2.d0*(ca*lambdag + 2.d0*gammastar*lambdag - a*vd))))/&
						(a*(ca + 2.d0*gammastar) ** 2.d0*vd*(ca*lambdag + 2.d0*&
						gammastar*lambdag - a*vd)))
				elsewhere
					gstomg=0.d0
				endwhere
				transpg=a*vd*gstomg								! (3.28)		transpiration rate in mol/s
				etmg=(transpg*18.d0)/(10.d0**6.d0)				! transpiration rate in m/s
			else
				par=0.d0
				jact=0.d0
				gstom=0.d0
				etm=0.d0
				jactg=0.d0
				gstomg=0.d0
				etmg=0.d0
			endif
!*-----SUB-HOURLY LOOPS --------------------------------------- 
!
			time=0.d0
			hass=0.d0											! hourly assimilation
			hassg=0.d0
			
			do while (time.lt.3600.d0)
!*********************************************************************
!*	Integrated Multi-layer Soil and Vegetation Water Balance Model
!*--------------------------------------------------------------------
!*	Model derived from waterbalanceHS7.nb
!*********************************************************************
!*----- setting variables from previous loop---------------------------
!
				rsurfvec(1:nlayersnew)=rsurfvec(1:nlayersnew)/(omgu*&
						delyuvec(1:nlayersnew))*omgunew*&
						delyunewvec(1:nlayersnew)
				if(nlayersnew.lt.pos) then
					rsurfvec(nlayersnew+1:pos)=rsurfmin*delyu
				endif
				rsurfg(1:nlayersnew)=rsurfg(1:nlayersnew)/(omgu*&
					delyuvec(1:nlayersnew))*omgunew*&
					delyunewvec(1:nlayersnew)
				if(nlayersnew.lt.posg) then
					rsurfvec(nlayersnew+1:pos)=rsurfmin*delyu
				endif
				mq=mqnew
				ys=ysnew
				suvec=sunewvec
				omgu=omgunew
				omgo=omgonew
				yu=yunew
				nlayers=nlayersnew
				delyuvec=delyunewvec
				wsvec=wsnewvec
				suvec=sunewvec
!*-----soil capillary pressure, infiltration and runoff--------------- 
!
				pcapvec(1:nlayers)= (-1.d0 + suvec(1:nlayers)**(-1.d0/mvg))**&	! (Out[54]), Chapter 3.3.2.3 
						(1.d0/nvg)/alphavg
				pcapvec(nlayers+1:M)=0.d0
				kunsatvec=ksat*Sqrt(suvec)*(-1.d0+(1.d0-suvec**&				! (3.14), (Out[55])
						(1.d0/mvg))**mvg)**2.d0
				postemp=Min(pos,nlayers)
				do i=1,postemp
				 phydrostaticvec(i)=(i-0.5d0)*delyu								! (Out[238]) hydrostatic head for (3.34) 	
				enddo
				prootmvec(1:postemp)= (mpbar*(-mq+mqx)*(750.d0 - (750.d0*mqx)/&	! (Out[239]) 
						(md + mqx) + (md + mqx)/mqx))/(md + mqx) - &
						phydrostaticvec(1:postemp)
				rsoilvec(1:postemp)=(Sqrt(Pi/2.d0)*Sqrt((rootrad*omgu*&			! soil resistance, (Out[ 241] with svolume=omgu*delyuvec(1:postemp)); derived from (3.32)
						delyuvec(1:postemp))/rsurfvec(1:postemp)))/&
						kunsatvec(1:postemp)
				ruptkvec(1:postemp)=((-pcapvec(1:postemp) + &					! root water uptake, Chapter 3.3.3.3 (Out[242])
						prootmvec(1:postemp))*rsurfvec(1:postemp))/(rrootm +&
						rsoilvec(1:postemp))
				ruptkvec(postemp+1:M)=0.d0							
				if(Maxval(etmg).gt.0.d0) then
					ruptkg(1:posg)=Max(0.d0,((-pcapvec(1:posg) + &				! root uptake by grasses can not be negative, as storage negligible
							(prootmg-phydrostaticvec(1:posg)))*rsurfg)/&
							(rrootm +(Sqrt(Pi/2.d0)*Sqrt(rootrad*omgu*&
							delyuvec(1:posg)/rsurfg))/kunsatvec(1:posg)))
					ruptkg(posg+1:M)=0.d0
					if(Sum(ruptkg).gt.0.d0) then
						where(etmg.gt.Sum(ruptkg)) 
							rootlim=1.d0
							etmg=Sum(ruptkg)
							transpg=etmg*55555.555555555555d0					! (Out[249])			mol/s=m/s*10^6 g/m/(18g/mol)
							gstomg=transpg/(a*vd)
						endwhere
						ruptkg(1:posg)=etmg(2,2)*(ruptkg(1:posg)/(Sum(ruptkg)))
					else
						ruptkg=0.d0
						rootlim=0.d0
						etmg=0.d0
						transpg=0.d0
						gstomg=0.d0
					endif
				else
					ruptkg=0.d0
				endif
				if (rain.gt.0.d0) then
					inf=Min((ksat+kunsatvec(1))/2.d0*omgu*(1.d0+(2.d0*&			! (3.6), (Out[60]) 
							pcapvec(1))/delyuvec(1)),omgu*rain)
					infx=rain-inf
				else	
					inf=0.d0
					infx=0.d0
				endif
				do i=1,nlayers-1
					qblvec(i)= -(omgu*(1.d0 + (-pcapvec(i) + pcapvec(i+1))/&	! (3.4), (Out[62]) 
							(0.5d0*delyuvec(i) + 0.5d0*delyuvec(i+1)))*&
							0.5d0*(kunsatvec(i) + kunsatvec(i+1)))
				enddo
				qblvec(nlayers)= -(omgu*(1.d0 + (-pcapvec(nlayers)/&			! (3.5), (Out[62]) 
							(0.5d0*delyuvec(nlayers))))*0.5d0*&
							(kunsatvec(nlayers)+ksat))
				esoil= 0.0002d0*(1.d0-0.8d0*(pc+pcg(2)))*par*suvec(1)*omgu		! (3.9), (Out[141])
				esoils= 0.0002d0*(1.d0-0.8d0*(pc+pcg(2)))*par*omgo				! (3.10), (Out[142], but suvec(1) instead of par removed)
				spgfcf= (0.5d0*ksat*omgo*(ys - zr))/(cgs*Cos(go))				! (3.7), (Out[61])
903				dys=(esoils + spgfcf + qblvec(nlayers))/(epsln*(-1.d0 +&		! (3.15), (Out[144], with suavg=Sum(suvec(....)/nlayers) 
							Sum(suvec(1:nlayers))/nlayers))
				dtys=99999d0
				if (dys.lt.0.d0) then											! preventing ys from becoming negative or time step of being too large
					if (ys.le.0.1d0*delyu) then
						qblvec(nlayers)=0.d0
						dys=0.d0
						dtys=99999.d0
					else
					dtys=Min(0.1d0*(-ys/dys),-0.01d0*delyu/dys)
					endif
				elseif (dys.gt.0.d0) then
					dtys=0.01d0*delyu/dys
				endif
				if(ys.gt.zr) then												
					domgu= -dys/(2.d0*Sqrt((cz - ys)*(cz - zr)))				! (Out[146])
					dyu= (dys*(-cz + zr))/(2.d0*Sqrt((cz - ys)*(cz - zr)))		! (Out[148])
					if(dys.le.0.d0) then
						dtys=Min(dtys,-(ys-zr)/dys)
					endif
				elseif(ys.lt.zr) then
					domgu=0.d0
					dyu=-dys	
					if(dys.gt.0.d0) then
						dtys=Min(dtys,(zr-ys)/dys)
					endif
				else
					domgu=0.d0
					dyu=-dys
				endif
!* MAKING SURE THAT NO SUBLAYER 'OVERFLOWS'
!
				if(Maxval(suvec(1:nlayers)).gt.0.999d0) then
					if(suvec(1).gt.0.999d0) then
						if(-esoil+inf+qblvec(1)-ruptkvec(1)-&
							ruptkg(1).gt.0.d0) then
							qblvec(1)=esoil - inf + ruptkvec(1)+ruptkg(1)		! (Out[156]) +ruptkg(1)
						endif	
					endif
					do i=2,nlayers-1
						if(suvec(i).gt.0.999d0) then
							if(-qblvec(i-1) + qblvec(i) - ruptkvec(i)-&
										ruptkg(i).gt.0.d0) then
								qblvec(i)=qblvec(i-1)+ruptkvec(i)+ruptkg(i)		! (Out[158])+ruptkg(i)
							endif
						endif
					enddo
				endif
!*-----steady-state tissue water (mqss) ---------------------------------------------- 
!
				mqss= Max(0.9d0*mqx,(mqx*(mpbar*(md*md+752.d0*md*mqx+mqx*mqx)*&	! (Out[257]) steady-state Mq
						Sum((rsurfvec(1:postemp)/&
						(rrootm + rsoilvec(1:postemp)))) - (md + mqx)*&
						(md+mqx)*(etm - Sum(((-phydrostaticvec(1:postemp) -&
						pcapvec(1:postemp))*rsurfvec(1:postemp))/&
						(rrootm + rsoilvec(1:postemp))))))/&
						(mpbar*(md*md + 752.d0*md*mqx + mqx*mqx)*&
						Sum((rsurfvec(1:postemp)/(rrootm + &
						rsoilvec(1:postemp))))))
				mqssmin=Min(mqssmin,mqss)
!*-----transpiration, gstom and tissue water ---------------------------------------------- 
!
				if (mq.le.0.9d0*mqx) then										! makes sure that tissue water does not get below 0.9mqx
					if (etm.gt.0.9d0*Sum(ruptkvec(1:nlayers))) then
						if (Sum(ruptkvec(1:nlayers)).ge.0.d0) then
							etm=Sum(ruptkvec(1:nlayers))
							transp=etm*55555.555555555555d0						! (Out[249])			mol/s=m/s*10^6 g/m/(18g/mol)
							gstom=transp/(a*vd)
						else
							write(6,'(a20,i2,a1,i2,a1,i4)') &
									'vegetation	dies on: ',&
									day(d),'/',month(d),'/',year(d)
							netass=0.d0
							RETURN												! if tissues water depleted, but still loosing water -> death
						endif
						mqss= Max(0.9d0*mqx,(mqx*(mpbar*(md*md+752.d0*md*mqx+&	! (Out[257]) steady-state Mq
							mqx*mqx)*Sum((rsurfvec(1:postemp)/&
							(rrootm + rsoilvec(1:postemp)))) - (md + mqx)*&
							(md+mqx)*(etm-Sum(((-phydrostaticvec(1:postemp)&
							-pcapvec(1:postemp))*rsurfvec(1:postemp))/&
							(rrootm + rsoilvec(1:postemp))))))/&
							(mpbar*(md*md + 752.d0*md*mqx + mqx*mqx)*&
							Sum((rsurfvec(1:postemp)/(rrootm + &
							rsoilvec(1:postemp))))))
						mqssmin=Min(mqssmin,mqss)
					endif	
				endif				
				dmq=(Sum(ruptkvec(1:nlayers))-etm)*1.d6							! (3.35), 1.e6 to convert from m (=1000kg/m2) to g/m2; (Out[250]) 				
				dtmq=99999.d0
				if (dmq.gt.0.d0) then											! avoids mq from becoming larger than mqx or smaller than 0.9mqx
					dtmq=(mqx-mq)/dmq
				elseif (dmq.lt.0.d0) then
					dtmq=(0.9d0*mqx-mq)/dmq
				endif
!*-----change in soil moisture ---------------------------------------------- 
!
				dtsu=99999.d0
				dsuvec(nlayers)=(qblvec(nlayers) - qblvec(nlayers-1) -&			! (3.17); (Out[151]) with added grass root uptake (ruptkg) to the equation
					ruptkvec(nlayers)-ruptkg(nlayers))/&
					(delyuvec(nlayers)*epsln*omgu)
				if (dsuvec(nlayers).gt.0.d0) then
					dtsu=Min(dtsu,0.9d0*(1.d0-suvec(nlayers))/dsuvec(nlayers),&
						suvec(nlayers)/(dsuvec(nlayers)*10.d0))
				elseif (dsuvec(nlayers).lt.0.d0) then
					dtsu=Min(dtsu,0.1d0*(-suvec(nlayers)/dsuvec(nlayers)))
				endif
				do i=2,nlayers-1												! (3.17); (Out[150]) with added ruptkg(i) 
					dsuvec(i)= (qblvec(i) - qblvec(i-1) - ruptkvec(i)-&
						ruptkg(i))/(delyuvec(i)*epsln*omgu)
					if (dsuvec(i).gt.0.d0) then
						dtsu=Min(dtsu,0.9d0*(1.d0-suvec(i))/dsuvec(i),suvec(i)/&
							(dsuvec(i)*10.d0))
					elseif (dsuvec(i).lt.0.d0) then
						dtsu=Min(dtsu,0.1d0*(-suvec(i)/dsuvec(i)))
					endif
				enddo
				dsuvec(1)=(-esoil + inf + qblvec(1) - ruptkvec(1)-&				! (3.16), (Out[149]) with added ruptkg(1)
					ruptkg(1))/(delyuvec(1)*epsln*omgu)
				if (dsuvec(1).gt.0.d0) then
					dtsu=Min(dtsu,0.9d0*(1.d0-suvec(1))/dsuvec(1),&
						suvec(1)/(dsuvec(1)*10.d0))
				elseif (dsuvec(1).lt.0.d0) then
					dtsu=Min(dtsu,0.1d0*(-suvec(1)/dsuvec(1)))
				endif
!*----- Calculating maximum time step -------------------------------------	
!
901				if(Abs(mq-mqss).gt.mqx/1.d6) then
					dtss=(mq-mqss)/(1.d6*(etm-Sum(ruptkvec(1:nlayers))))
					if(dtss.le.0.d0) then
						dtss=9999.d0
					endif
				else
					dtss=9999.d0
				endif
				dt=Min(dtss,dtmq,dtsu,dtys,3600.d0-time)
				if(dt.eq.dtss) then			
					pcapnewvec(1:nlayers)= (-1.d0 + (suvec(1:nlayers)+&			! (Out[54]) 
						dsuvec(1:nlayers)*dt)**(-1.d0/mvg))**(1.d0/nvg)/alphavg
					pcapnewvec(nlayers+1:M)=0.d0
					mqssnew=Max(0.9d0*mqx,(mqx*(mpbar*(md*md+752.d0*md*mqx+&	! (Out[257]) steady-state Mq
						mqx*mqx)*Sum((rsurfvec(1:postemp)/&
						(rrootm + rsoilvec(1:postemp)))) - (md + mqx)*&
						(md+mqx)*(etm-Sum(((-phydrostaticvec(1:postemp)&
						-pcapvec(1:postemp))*rsurfvec(1:postemp))/&
						(rrootm + rsoilvec(1:postemp))))))/&
						(mpbar*(md*md + 752.d0*md*mqx + mqx*mqx)*&
						Sum((rsurfvec(1:postemp)/(rrootm + &
						rsoilvec(1:postemp))))))
					if(Abs(mqssnew-mqss).gt.mqx/1.d4) then
						mqss=mqss+0.5d0*(mqssnew-mqss)
						go to 901
					endif
				endif
!*----- Calculating state variables at next time step-----------------------	
!			
				time=time+dt
				mqnew=mq+dmq*dt
				ysnew=ys+dys*dt
				sunewvec(1:nlayers)=suvec(1:nlayers)+dt*dsuvec(1:nlayers)
				if(ysnew.gt.zr) then
					omgunew=(cz - ysnew)/Sqrt((cz - ysnew)*(cz - zr))
				else 
					omgunew=1.d0
				endif
				omgonew=1.d0-omgunew
				yunew=(cz-ysnew)/omgunew
				io=dt*(inf-esoil-esoils-spgfcf-Sum(ruptkvec(1:nlayers))-&		! (3.19)
					Sum(ruptkg(1:nlayers)))
				nlayersnew=Floor(yunew/delyu)
				delyunewvec(:)=delyu
				delyunewvec(nlayersnew)=yunew - (nlayersnew - 1)*delyu
				wsnewvec(1:nlayersnew-1)= sunewvec(1:nlayersnew-1)*epsln*&		! (3.18) 
					omgunew*delyunewvec(1:nlayersnew-1)
				wsnewvec(nlayersnew)= Sum(wsvec(1:nlayers))+ys*epsln+io -&		! (3.20) 
					Sum(wsnewvec(1:nlayersnew-1))-ysnew*epsln
				sunewvec(nlayersnew)= wsnewvec(nlayersnew)/&					! (3.21) 	
					(epsln*delyunewvec(nlayersnew)*omgunew)
				sunewvec(nlayersnew+1:M)= 1.d0
!*----- adding up hourly fluxes------------------------------------
!
				ass= (4.d0*ca*gstom + 8.d0*gammastar*gstom + jact - 4.d0*rl - &		! (3.22); (Out[319])
					Sqrt((-4.d0*ca*gstom + 8.d0*gammastar*gstom + jact - &
					4.d0*rl)**2.d0 + &
					16.d0*gammastar*gstom*(8.d0*ca*gstom + jact + 8.d0*rl)))/8.d0
				hass=hass+ass*dt
				assg= (4.d0*ca*gstomg + 8.d0*gammastar*gstomg+jactg - 4.d0*rlg-&	! (3.22); (Out[319])
					Sqrt((-4.d0*ca*gstomg + 8.d0*gammastar*gstomg + jactg - &
					4.d0*rlg)**2.d0 + &
					16.d0*gammastar*gstomg*(8.d0*ca*gstomg + jactg + 8.d0*rlg)))/8.d0
				hassg=hassg+assg*dt
				hruptkvec=hruptkvec+ruptkvec*dt
				if (optmode.eq.0) then
					hspgfcf=hspgfcf+dt*spgfcf
					hinfx=hinfx+dt*infx
					hio=hio+io
					hesoil=hesoil+dt*(esoil+esoils)
					hetm=hetm+dt*etm
					hetmg=hetmg+dt*etmg(2,2)	
					hruptk=hruptk+dt*Sum(ruptkvec(1:nlayers))
					hinf=hinf+inf*dt
				endif		
!*------END OF HOUR----------------------------------------------------
!
		enddo
		netass=netass+hass(2)-3600.d0*(cpcc+rr+tc)+hassg(2,2)-3600.d0*&
				(cpccg(2)+rrg+tcg(2))											! rl does not need to be included here as ass=-rl if j=0 (at night)
		ass_d=ass_d+hass	
		assg_d=assg_d+hassg	
		ruptkvec_d=ruptkvec_d+hruptkvec
		if (optmode.eq.0) then
			netassvec(d)=netassvec(d)+hass(2)-3600.d0*(cpcc+rr+tc)
			netassvecg(d)=netassvecg(d)+hassg(2,2)-3600.d0*&
				(cpccg(2)+rrg+tcg(2))											! rl does not need to be included here as ass=-rl if j=0 (at night)
!*----- summary------------------------------------------------------
!
			ruptk_d=ruptk_d+Sum(ruptkvec(1:nlayers))*3600.d0
			vd_d=vd_d+vd
			jmax_d=jmax_d+jmax(2)
			jmaxg_d=jmaxg_d+jmaxg(2)
			gstom_d=gstom_d+gstom
			gstomg_d=gstomg_d+gstomg(2,2)
			etm_d=etm_d+hetm
			etmg_d=etmg_d+hetmg
			esoil_d=esoil_d+hesoil
			spgfcf_d=spgfcf_d+hspgfcf
			infx_d=infx_d+hinfx
			rl_d=rl_d+rl(2)*3600.d0												! rl_d in mol/day
			rlg_d=rlg_d+rlg(2,2)*3600.d0
			write(str,'(i3)') nlayers											!internal write to convert from number to string
			dailyformat='(i6,i6,i4,i7,'//str//'e14.6)'							! includes a column for each sublayer 
			hourlyformat='(i6,i6,i4,i7,i5,'//str//'e14.6)'						! includes a column for each sublayer
			if(year(d).ge.firstyear.and.year(d).le.lastyear)then
				write(201,102)year(d),month(d),day(d),d,h,rain,&
					tair,par,vd,hesoil,pc+pcg(2),&
					jmax25(2),jmax25g(2),mq,rl(2)+rlg(2,2),lambda,lambdag,rr+rrg,&
					hass(2),hassg(2,2),hetm,hetmg,suvec(1),ys,&
					wsnew,omgo,hspgfcf,hinfx
				write(205,hourlyformat) year(d),month(d), day(d),d,h,delyuvec(1:nlayers)
				write(206,hourlyformat) year(d),month(d), day(d),d,h,hruptkvec(1:nlayers)
				write(207,hourlyformat) year(d),month(d), day(d),d,h,suvec(1:nlayers)
			endif
!*----- check water balance -----------------------------------------
!
			iocum=iocum+hio
			wsnew=ysnew*epsln + Sum(wsnewvec(1:nlayersnew))	
			error=wsold+iocum-wsnew
			if(abs(error/wsold).gt.1.d-6) then									! gives an error message if accumulated error exceeds 10^-4 of ws
				write(6,*)'Error in water balance [%]:',error*100.d0,'in=',in,&
     					'io=',io,'wsold=',wsold,'wsnew=',wsnew
			endif
			error1=mqold+(hruptk-hetm)*1.d6-mqnew
			if(abs(error1/mqnew).gt. 1.d-6) then
				write(6,*)'Error in tree water balance [%]:',error1*100.d0,'mqold=',mqold,&
     					'mqnew=',mqnew,'hruptk=',hruptk,'hetm=',hetm
			endif
			mqold=mqnew
			hspgfcf=0.d0
			hinfx=0.d0
			hio=0.d0
			hesoil=0.d0
			hetm=0.d0
			hetmg=0.d0
			hruptk=0.d0
			hinf=0.d0
		endif
		hass=0.d0
		hassg=0.d0
		hruptkvec=0.d0
	enddo
!*------END OF DAY----------------------------------------------------
!
	if (optmode.eq.0) then
		write(202,102)year(d),month(d),day(d),d,h,rainvec(d),&
			tmax(d),tmin(d),parvec(d),vd_d/24.d0,esoil_d,&
			jmax25(2),jmax25g(2),pc+pcg(2),rl_d+rlg_d,lambda,lambdag,&
			rr*3600.d0*24.d0,rrg*3600.d0*24.d0,ass_d(2),assg_d(2,2),&
			Sum(suvec(1:nlayers))/nlayers,ys,wsnew,spgfcf_d,&
			infx_d,etm_d,etmg_d,suvec(1)
		write(204,dailyformat) year(d),month(d), day(d),d,rsurfvec(1:nlayers)
		if(year(d).eq.yr) then
			rainyr=rainyr+rainvec(d)										! in [mm]
			epanyr=epanyr+epan(d)											! epan originally in [mm]/day
			paryr=paryr+parvec(d)
			radyr=radyr+srad(d)												! srad originally in MJ/day
			vdyr=vdyr+vd_d/24.d0
			etyr=etyr+(etm_d+etmg_d)*1000.d0								! in[mm]
			evapyr=evapyr+esoil_d*1000.d0									! in [mm]
			netassyr=netassyr+ass_d(2)-(cpcc+rr)*3600.d0*24.d0+&
				assg_d(2,2)	-(cpccg(2)+rrg)*3600.d0*24.d0
			gppyr=gppyr+(ass_d(2)+rl_d)+assg_d(2,2)+rlg_d
		else
			write(203,'(i6,9e15.6)') yr,rainyr,epanyr,paryr,radyr,vdyr/&
				(dayyear(d)),etyr,evapyr,netassyr,gppyr
			yr=year(d)
			rainyr=rainvec(d)
			epanyr=epan(d)													! epan originally in [mm]/day
			paryr=parvec(d)
			radyr=srad(d)													! srad originally in MJ/day
			vdyr=vd_d/24.d0
			etyr=(etmg_d+etm_d)*1000.d0
			evapyr=esoil_d*1000.d0
			netassyr=ass_d(2)-(cpcc+rr)*3600.d0*24.d0+assg_d(2,2)-&
				(cpccg(2)+rrg)*3600.d0*24.d0	
			gppyr=(ass_d(2)+rl_d)+assg_d(2,2)+rlg_d
		endif	
		ruptk_d=0.d0
		vd_d=0.d0
		jmax_d=0.d0
		jmaxg_d=0.d0
		gstom_d=0.d0
		gstomg_d=0.d0
		etm_d=0.d0
		etmg_d=0.d0
		esoil_d=0.d0
		spgfcf_d=0.d0
		infx_d=0.d0
		rl_d=0.d0
		rlg_d=0.d0
	endif
!*------ADJUSTMENT OF JMAX25 and PC------------------------------------
!
	pos1=Maxloc(ass_d)		
	jmax25(2)=jmax25(pos1(1))
	ass_d=0.d0
	netassg_d(1,:)=assg_d(1,:)-3600.d0*24.d0*(cpccg(1)+rrg+tcg(1))
	netassg_d(2,:)=assg_d(2,:)-3600.d0*24.d0*(cpccg(2)+rrg+tcg(2))
	netassg_d(3,:)=assg_d(3,:)-3600.d0*24.d0*(cpccg(3)+rrg+tcg(3))
	pos2=Maxloc(netassg_d)
	pcg(2)=Min(1.d0-pc,pcg(pos2(1)))
	jmax25g(2)=jmax25g(pos2(2))
	assg_d=0.d0
!*------ADJUSTMENT OF ROOT SURFACE------------------------------------
!
	reff=0.d0
	changef= (0.95d0*mqx - mqssmin)/(0.05d0*mqx)							! (3.47)
	reff(1:pos) = 0.5d0*ruptkvec_d(1:pos)/&									! (3.48)
		rsurfvec(1:pos)/(Maxval(ruptkvec_d(1:pos)/rsurfvec(1:pos)))
	where(ruptkvec_d(1:pos).lt.0.d0) 
		reff=0.d0
	endwhere
	if(changef.lt.0.d0) then
		reff=1.d0-reff
	endif
	rsurfnewvec(1:pos)=Min(2.d0*epsln/rootrad*delyu*omgu,&					! rsurf=(2*epsln/rootrad) if all pores filled by roots
		Max(rsurfmin,rsurfvec(1:pos)+growthmax*changef*&
		reff(1:pos)*omgu*delyu))
	where(rsurfvec.gt.1.d0) 
		rsurfnewvec=Min(2.d0*epsln/rootrad*delyu*omgu,&
			Max(rsurfmin*delyu*omgu,rsurfvec(1:pos)+&
			rsurfvec*growthmax*changef*reff(1:pos)*omgu*delyuvec))
	endwhere
	rsurfgnew(1:posg)=Min(2.d0*epsln/rootrad*delyuvec(1:posg)*&
		omgu-rsurfvec(1:posg),&
		Max(rsurfmin*delyuvec(1:posg)*omgu,rsurfg(1:posg)*&
		(0.9d0+0.2d0*rootlim(pos2(1),pos2(2)))))							! maximum rsurfg depends on rsurf of trees in same layer.
	rsurfgnew(posg+1:M)=0.d0
	rootlim=0.d0
	ruptkvec_d=0.d0
enddo
!*------END OF DAILY LOOPS----------------------------------------------
!
if (d.lt.N) then
	if (netass.le.0.d0) then
		netass=netass/nyt*ny												! estimates how bad the carbon loss 
																			! would be instead of running through
																			! the whole set
	else			
		dtest=N
		goto 902
	endif
endif

101	format(a6,a7,a7,a7,a7,24a15)
102	format(i6,i7,i7,i7,i7,24e15.5)
103	format(e15.5)
	close (201)
	close (202)
	close (203)
	close (204)
	close (205)
	close (206)
	close (207)
	return
end subroutine transpmodel


