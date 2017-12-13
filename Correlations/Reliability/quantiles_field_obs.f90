program quantiles_field_obs

!   Compute quantiles of a set of fields using all ensemble members
!   but weighing each model equally.

    implicit none
    include 'params.h'
    include 'netcdf.inc'
    integer :: nvarmax,ntmax
    parameter (nvarmax=20,ntmax=12)
    integer :: i,j,nens,iens,fyr,yr1,yr2,imod,nmod,nskip,nensmin,nbins,nbins1
    integer :: ix,iy,iz,mo,lastmo,ntvarid,itimeaxis(ntmax),it,status
    integer :: mens1,mens,ncid,nx,ny,nz,nt,nperyear,ivar,iiens &
        ,firstyr,firstmo,endian,nvars,jvars(6,nvarmax) &
        ,ivars(2,nvarmax),firstens(100)
    integer,allocatable :: nnens(:),nnens1(:),nnmod(:)
    real :: xx(nxmax),yy(nymax),zz(nzmax), &
        wx(nxmax),wy(nymax),wz(nzmax),undef,ww,hh(100),pcut
    real,allocatable :: field(:,:,:,:,:,:),quantiles(:,:,:,:,:) &
        ,sdmod(:,:,:,:,:),sd(:,:,:,:),obs(:,:,:,:,:),perc(:,:,:,:) &
        ,hist(:,:),histlo(:,:),histhi(:,:)
    real,allocatable :: field1(:,:,:,:,:,:),quantiles1(:,:,:,:,:) &
        ,perc1(:,:,:,:),hist1(:,:,:)
    character infile*255,outfile*255,datfile*255,lz(3)*20,ltime*100 &
        ,title*255,history*10000,vars(nvarmax)*40 &
        ,lvars(nvarmax)*140,svars(nvarmax)*100,units(nvarmax)*100 &
        ,cell_methods(nvarmax)*100,string*255
    character var*20,model*20,trend*20,rip*20,yrs*20,oldmodel*20
    character models(100)*20,inunts*40
    logical :: lwrite,lstandardunits,xrev,yrev,xwrap,lnatural
    integer :: iargc

    lwrite = .false. ! .true. 
    lstandardunits = .false. 
    nensmin = 4             ! minimum number of ensemble members to base a sd on
    nbins = 20

    if ( iargc() < 3 ) then
        write(0,*) 'usage: quantiles_field obsfile infile1 infile2 ... outfile'
        write(0,*) 'computes the quantile of the obs in a '// &
            'multi-model ensemble. Each file should correspond '// &
            'to one ensemble member.'
        call abort
    end if

!   read data

    call getarg(1,infile)
            
    nens = iargc() - 2
    call getmetadata(infile,mens1,mens,ncid,datfile,nxmax,nx &
        ,xx,nymax,ny,yy,nzmax,nz,zz,lz,nt,nperyear,firstyr &
        ,firstmo,ltime,undef,endian,title,history,nvarmax,nvars &
        ,vars,jvars,lvars,svars,units,cell_methods,lwrite)
    call getxyprop(xx,nx,yy,ny,xrev,yrev,xwrap)
    call getweights('x',xx,wx,nx,xwrap,lwrite)
    call getweights('y',yy,wy,ny, .false. ,lwrite)
    wz = 1 ! for the time being
    if ( nz > 1 ) then
        write(0,*) 'warning: all levels are weighed equally!'
    end if
    fyr = firstyr
    yr1 = firstyr
    yr2 = firstyr
    allocate(obs(nx,ny,nz,nperyear,fyr:fyr))
    call readfield(ncid,infile,datfile,obs(1,1,1,1,fyr) &
        ,nx,ny,nz,nperyear,fyr,fyr,0,0,nx,ny,nz,nperyear,yr1 &
        ,yr2,firstyr,firstmo,nt,undef,endian,vars,units &
        ,lstandardunits,lwrite)
    nskip  = 0
    do iens=1,nens
        call getarg(iens+1,infile)
        call getmetadata(infile,mens1,mens,ncid,datfile,nxmax,nx &
            ,xx,nymax,ny,yy,nzmax,nz,zz,lz,nt,nperyear,firstyr &
            ,firstmo,ltime,undef,endian,title,history,nvarmax,nvars &
            ,vars,jvars,lvars,svars,units,cell_methods,lwrite)
        if ( nt+firstmo-1 > nperyear ) then
            write(0,*) 'quantiles_field: error: can only handle one' &
                ,' year of data in each field, not ',firstmo,+nt-1
            call abort
        end if
        if ( iens == 1 ) then
            fyr = firstyr
            yr1 = firstyr
            yr2 = firstyr
            allocate(field(nx,ny,nz,nperyear,fyr:fyr,nens))
            allocate(nnmod(nens))
            allocate(nnens(nens))
            allocate(quantiles(nx,ny,nz,nperyear,-7:7))
            allocate(perc(nx,ny,nz,nperyear))
            nmod = 0
            nnmod = 0
            oldmodel = ' '
        end if
        call parsename(infile,var,model,trend,rip,yrs,lwrite)
        if ( model == 'modmean' .or. model == 'onemean' .or. &
             model == 'modmedian' ) then
            write(0,*) 'skipping ',trim(model)
            nskip = nskip + 1
            cycle
        end if
        if ( model /= oldmodel ) then
            nmod = nmod + 1
            nnmod(nmod) = 0
            models(nmod) = model
            oldmodel = model
            firstens(nmod) = iens
        end if
        nnmod(nmod) = nnmod(nmod) + 1
        call readfield(ncid,infile,datfile,field(1,1,1,1,fyr,iens) &
            ,nx,ny,nz,nperyear,fyr,fyr,0,0,nx,ny,nz,nperyear,yr1 &
            ,yr2,firstyr,firstmo,nt,undef,endian,vars,units &
            ,lstandardunits,lwrite)
    end do
    allocate(sdmod(nx,ny,nz,nperyear,nmod))
    allocate(sd(nx,ny,nz,nperyear))
    nens = nens - nskip
    lastmo = firstmo + nt - 1
    nbins = min(nbins,nens)
    allocate(hist(nbins,nperyear))

!   how many ensemble members per model?

    print '(a)','# file generated by the command '
    do i=0,iargc()
        call getarg(i,string)
        print '(2a)','# ',trim(string)
    end do
    print '(a,i3,a,i4,a)','# Found ',nmod,' models with in all ',nens,' ensemble members:'
!
!   if only a single model, treat all ensemble members equal
!
    if ( nmod == 1 ) then
        nmod = nens
        nnmod(1:nens) = 1
        models(2:nens) = models(1)
        do iens=1,nens
            firstens(iens) = iens
        end do
    end if
!
!   go on
!
    iens = 0
    do imod=1,nmod
        if ( lwrite ) print *,imod,nnmod(imod),' ',trim(models(imod))
        do i=1,nnmod(imod)
            iens = iens + 1
            nnens(iens) = nnmod(imod)
        end do
    end do
    if ( iens /= nens ) then
        write(0,*) 'quantiles_field: error: something went wrong ',iens,nens
        call abort
    end if

!   compute  min,max,fixed set,obs in PDF defined by field

    call getweightedobsquantile(obs,field,nnens,nx,ny,nz,nperyear, &
        nens,firstmo,lastmo,nmod,quantiles,perc,lwrite)

!   compute reliability histogram

    call getreliabilityhistogram(perc,nx,ny,nz,nperyear,xx,yy, &
        zz,wx,wy,wz,nbins,firstmo,lastmo,hist,lwrite)

!   compute significance interval for reliability histogram
!   by taking the first ensemble member of each model in turn
!   as pseudo-observations

    nbins1 = min(nbins,nens-1)
    allocate(field1(nx,ny,nz,nperyear,fyr:fyr,nens))
    allocate(quantiles1(nx,ny,nz,nperyear,-7:7))
    allocate(perc1(nx,ny,nz,nperyear))
    allocate(hist1(nbins1,nperyear,nmod))
    allocate(nnens1(nens))
    allocate(histlo(nbins1,nperyear))
    allocate(histhi(nbins1,nperyear))

    do imod=1,nmod
        if ( lwrite ) print *,'model ',imod
        iiens = 0
        do iens=1,nens
            if ( iens < firstens(imod) .or. &
                 imod < nmod .and. iens >= firstens(min(imod+1,nmod)) ) then
                iiens = iiens + 1
                if ( lwrite ) print *,'copying ',iens,' to ',iiens
                do it=firstmo,lastmo
                    do iz=1,nz
                        do iy=1,ny
                            do ix=1,nx
                                field1(ix,iy,iz,it,fyr,iiens) = field(ix,iy,iz,it,fyr,iens)
                            end do
                        end do
                    end do
                end do
                nnens1(iiens) = nnens(iiens)
            end if
        end do
        call getweightedobsquantile(field(1,1,1,1,fyr, &
            firstens(imod)),field1,nnens1,nx,ny,nz,nperyear, &
            iiens,firstmo,lastmo,nmod-1,quantiles1,perc1,lwrite)
        call getreliabilityhistogram(perc1,nx,ny,nz,nperyear,xx,yy, &
            zz,wx,wy,wz,nbins1,firstmo,lastmo,hist1(1,1,imod),lwrite)
    end do

!   compute natural variability

    sdmod = 3e33
    iens = 0
    lnatural = .false.
    do imod=1,nmod
        iens = iens + nnmod(imod)
        if ( nnmod(imod) >= nensmin ) then
            call getnaturalvariability(field(1,1,1,1,fyr,iens) &
                ,nx,ny,nz,nperyear,nnmod(imod),firstmo,lastmo &
                ,sdmod(1,1,1,1,imod),lwrite)
            lnatural = .true.
        end if
    end do
    if ( lnatural ) then
        call averagefields(sdmod,nx,ny,nz,nperyear,nmod,firstmo,lastmo,sd,lwrite)
    end if

!   write histogram to stdout

    do it=firstmo,lastmo
        ww = 0
        do i=1,nbins
            ww = ww + hist(i,it)
            print '(2f5.2,2f7.4)',max(0.,(i-1.)/nbins),min(1.,real(i)/nbins),hist(i,it),ww
        end do
        print '(a,i2)','1 1 0 1     histogram month ',it
        print '(a)'
    end do
    print '(a)'             ! index 1
    do imod=1,nmod
        print '(2a)','# ',trim(models(imod))
        do it=firstmo,lastmo
            ww = 0
            do i=1,nbins1
                ww = ww + hist(i,it)
                print '(2f5.2,2f7.4)',max(0.,(i-1.)/nbins1),min(1.,real(i)/nbins1),hist1(i,it,imod),ww
            end do
            print '(a,i3,a,i2)','1 1 0 1     noise MC ',imod,' month ',it
            print '(a)'
        end do
    end do
    do it=firstmo,lastmo
        do i=1,nbins1
        !   compute 95% CI per bin
            do imod=1,nmod
                hh(imod) = hist1(i,it,imod)
            end do
            pcut = 5
            call getcut(histlo(i,it),pcut,nmod,hh)
            pcut = 95
            call getcut1(histhi(i,it),pcut,nmod,hh,lwrite)
        end do
    end do
    print '(a)'             ! index 2
    print '(a)','# 5%, 95%'
    do it=firstmo,lastmo
        print '(2f5.2,2f7.4)',0.,0.,histlo(1,it),histhi(1,it)
        do i=1,nbins1
            print '(2f5.2,2f7.4)',max(0.,(i-1.)/nbins1), &
                min(1.,real(i)/nbins1),histlo(i,it),histhi(i,it)
        end do
        print '(2f5.2,2f7.4)',1.,1.,histlo(nbins1,it),histhi(nbins1,it)
        print '(a)'
    end do

!   write output to file

    nvars = 0
    call definevariable(nvars,vars,lvars,'min','minimum of all ensemble members')
    call definevariable(nvars,vars,lvars,'p025','2.5% quantile')
    call definevariable(nvars,vars,lvars,'p05','5% quantile')
    call definevariable(nvars,vars,lvars,'p10','10% quantile')
    call definevariable(nvars,vars,lvars,'p20','20% quantile')
    call definevariable(nvars,vars,lvars,'p25','25% quantile')
    call definevariable(nvars,vars,lvars,'p40','40% quantile')
    call definevariable(nvars,vars,lvars,'p50','50% quantile')
    call definevariable(nvars,vars,lvars,'p60','60% quantile')
    call definevariable(nvars,vars,lvars,'p75','75% quantile')
    call definevariable(nvars,vars,lvars,'p80','80% quantile')
    call definevariable(nvars,vars,lvars,'p90','90% quantile')
    call definevariable(nvars,vars,lvars,'p95','95% quantile')
    call definevariable(nvars,vars,lvars,'p975','97.5% quantile')
    call definevariable(nvars,vars,lvars,'max' ,'maximum of all ensemble members')
    call definevariable(nvars,vars,lvars,'perc','quantile of observations in ensemble')
    call definevariable(nvars,vars,lvars,'sd','standard deviation from intra-model spread')
    do ivar=1,nvars
        if ( ivar == 1 ) then
            units(ivar) = '1'
        else
            units(ivar) = units(1)
        end if
        ivars(1,ivar) = nz
        ivars(2,ivar) = 99
    end do

    title = 'Quantiles of the multi-model ensemble'
    call getarg(iargc(),outfile)
    call writenc(outfile,ncid,ntvarid,itimeaxis,ntmax,nx,xx,ny,yy &
        ,nz,zz,nt,nperyear,firstyr,firstmo,3e33,title,nvars &
        ,vars,ivars,lvars,units,0,0)
    do it=1,nt
        do ivar=1,nvars
            if ( ivar <= 15 ) then
                call writencslice(ncid,ntvarid,itimeaxis,ntmax &
                    ,ivars(1,ivar),quantiles(1,1,1,firstmo+it-1 &
                    ,ivar-8),nx,ny,nz,nx,ny,nz,it,1)
            else if ( ivar == 16 ) then
                call writencslice(ncid,ntvarid,itimeaxis,ntmax &
                    ,ivars(1,ivar),perc(1,1,1,firstmo+it-1), &
                    nx,ny,nz,nx,ny,nz,it,1)
            else if ( ivar == nvars ) then
                call writencslice(ncid,ntvarid,itimeaxis,ntmax &
                    ,ivars(1,ivar),sd(1,1,1,firstmo+it-1),nx,ny,nz &
                    ,nx,ny,nz,it,1)
            else
                write(0,*) 'quantiles_field: error: unknown ivar =' &
                ,ivar,nvars
            end if
        end do
    end do
    status = nf_close(ncid)

 end program

subroutine oldparsename(file,var,model,trend,rip,yrs,lwrite)

!       parse the old standard file name

    implicit none
    integer :: i0,i
    character file*(*),var*(*),model*(*),trend*(*),rip*(*),yrs*(*)
    logical :: lwrite
    i0 = 1 + index(file,'/', .true. )
    if ( lwrite ) print *,'file name = ',trim(file(i0:))
    i = i0 + index(file(i0:),'_') - 1
    if ( i == i0 .or. &
    file(i0:i-1) /= 'diff' .and. file(i0:i-1) /= 'pdiff' .and. &
    file(i0:i-1) /= 'regr' ) then
        write(0,*) 'parsename: error: expecting a file name that ', &
            'starts with "diff_", not ',trim(file),' ',file(i0:i-1)
        call abort
    end if
    i0 = i + 1
    call parsename_next(file,i0,i,var,'var',lwrite)
    call parsename_next(file,i0,i,model,'model',lwrite)
    if ( model(2:4) == 'mon' .or. model(3:4) == 'mon' ) then
    !           Amon, Omon, Lmon, OImon... try the next field
        call parsename_next(file,i0,i,model,'model',lwrite)
    end if
    call parsename_next(file,i0,i,trend,'trend',lwrite)
    call parsename_next(file,i0,i,rip,'rip',lwrite)
    call parsename_next(file,i0,i,rip,'yrs',lwrite)

end subroutine

subroutine parsename(file,var,model,trend,rip,yrs,lwrite)

!       parse a standard file name

    implicit none
    integer :: i0,i
    character file*(*),var*(*),model*(*),trend*(*),rip*(*),yrs*(*)
    logical :: lwrite
    i0 = 1 + index(file,'/', .true. )
    if ( lwrite ) print *,'file name = ',trim(file(i0:))
    i = i0 + index(file(i0:),'_') - 1
    if ( i == i0 .or. &
    file(i0:i-1) /= 'diff' .and. file(i0:i-1) /= 'pdiff' .and. &
    file(i0:i-1) /= 'regr' ) then
        write(0,*) 'parsename: error: expecting a file name that ', &
            'starts with "diff_", not ',trim(file),' ',file(i0:i-1)
        call abort
    end if
    i0 = i + 1
    call parsename_next(file,i0,i,var,'var',lwrite)
    call parsename_next(file,i0,i,model,'model',lwrite)
    call parsename_next(file,i0,i,trend,'trend',lwrite)
    if ( trend(1:1) == 'p' .and. len_trim(trend) <= 3 ) then
    ! it is a pN physics number
        model = trim(model)//'_'//trim(trend)
        call parsename_next(file,i0,i,trend,'trend',lwrite)
    end if
    call parsename_next(file,i0,i,rip,'yrs',lwrite)
    call parsename_next(file,i0,i,rip,'rip',lwrite)

end subroutine

subroutine parsename_next(file,i0,i,var,name,lwrite)
    implicit none
    integer :: i0,i
    character file*(*),var*(*),name*(*)
    logical :: lwrite

    i = i0 + index(file(i0:),'_') - 1
    if ( i == i0 ) then
        write(0,*) 'parsename: error: cannot find ',name,' in ',trim(file),i0
        call abort
    end if
    var = file(i0:i-1)
    if ( lwrite ) print *,trim(name),' = ',trim(var)
    i0 = i + 1

end subroutine

subroutine getweightedobsquantile(obs,field,nnens,nx,ny,nz, &
    nperyear,nens,firstmo,lastmo,nmod,quantiles,perc,lwrite)

!   compute the weighted quantile of field using the number of
!   ensemble members in nn as weighting information

    implicit none
    integer :: nnens(nens),nx,ny,nz,nperyear,nens,firstmo,lastmo,nmod
    real :: obs(nx,ny,nz,nperyear,1),field(nx,ny,nz,nperyear,1,nens)
    real :: quantiles(nx,ny,nz,nperyear,-7:7),perc(nx,ny,nz,nperyear)
    logical :: lwrite
    integer :: ix,iy,iz,mo,iens,iquant
    real :: quant(-7:7),obspoint
    real,allocatable :: point(:)

    allocate(point(nens))
    if ( lwrite ) print *,'getweightedquantile: ',nx,ny,nz,nperyear,nens
    do mo=firstmo,lastmo
        do iz=1,nz
            do iy=1,ny
                do ix=1,nx
                    do iens=1,nens
                        point(iens) = field(ix,iy,iz,mo,1,iens)
                    end do
                    obspoint = obs(ix,iy,iz,mo,1)
                    call getweightedobsquant(obspoint,point,nnens &
                        ,nens,nmod,quant,perc(ix,iy,iz,mo),lwrite)
                    do iquant = -7,7
                        quantiles(ix,iy,iz,mo,iquant) = &
                        quant(iquant)
                    end do
                end do
            end do
        end do
    end do
    deallocate(point)

end subroutine

subroutine getnaturalvariability(field,nx,ny,nz,nperyear,nens &
    ,firstmo,lastmo,sdmod,lwrite)

!       compute an estimate of the natural variability from the spread
!       of the nens ensemble members of one model

    implicit none
    integer :: nx,ny,nz,nperyear,nens,firstmo,lastmo
    real :: field(nx,ny,nz,nperyear,1,nens),sdmod(nx,ny,nz,nperyear)
    logical :: lwrite
    integer :: ix,iy,iz,mo,iens,n
    real :: ave,adev,sdev,var,skew,curt
    real,allocatable :: xx(:)
            
    if ( nens < 4 ) then
        write(0,*) 'getnaturalvariability: error: need more than ' &
            ,nens,' ensemble members'
        sdmod = 3e33
        return
    end if
    allocate(xx(nens))
    do mo=firstmo,lastmo
        do iz=1,nz
            do iy=1,ny
                do ix=1,nx
                    n = 0
                    do iens=1,nens
                        if ( field(ix,iy,iz,mo,1,iens) < 1e33 ) then
                            n = n + 1
                            xx(n) = field(ix,iy,iz,mo,1,iens)
                        end if
                    end do
                ! Numerical recipes routine
                    if ( n >= 4 ) then
                        call moment(xx,n,ave,adev,sdev,var,skew,curt)
                        sdmod(ix,iy,iz,mo) = sdev
                    else
                        sdmod(ix,iy,iz,mo) = 3e33
                    end if
                end do
            end do
        end do
    end do
    deallocate(xx)

end subroutine

subroutine averagefields(sdmod,nx,ny,nz,nperyear,nmod &
    ,firstmo,lastmo,sd,lwrite)

!   average the fields in sdmod (one per mdoel) with equal weights

    implicit none
    integer :: nx,ny,nz,nperyear,nmod,firstmo,lastmo
    real :: sdmod(nx,ny,nz,nperyear,nmod),sd(nx,ny,nz,nperyear)
    logical :: lwrite
    integer :: ix,iy,iz,mo,imod,n
    real :: s
            
    do mo=firstmo,lastmo
        do iz=1,nz
            do iy=1,ny
                do ix=1,nx
                    n = 0
                    s = 0
                    do imod=1,nmod
                        if ( sdmod(ix,iy,iz,mo,imod) < 1e33 ) then
                            n = n + 1
                            s = s + sdmod(ix,iy,iz,mo,imod)
                        end if
                    end do
                    if ( n >= 2 ) then
                        sd(ix,iy,iz,mo) = s/n
                    else
                        sd(ix,iy,iz,mo) = 3e33
                    end if
                end do
            end do
        end do
    end do

end subroutine

subroutine definevariable(nvars,vars,lvars,name,lname)
    implicit none
    integer :: nvars
    character vars(nvars+1)*(*),lvars(nvars+1)*(*), &
    name*(*),lname*(*)
    nvars = nvars + 1
    vars(nvars) = name
    lvars(nvars) = lname
!!!print *,'vars(',nvars,') = ',trim(name)
end subroutine

            