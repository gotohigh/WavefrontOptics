% Script:  v_AutruesseauData
%
% Recreate Figure 11 from Autrusseau et al.
% History:
%   4/29/12	 dhb  Created.
%
% (c) Wavefront Toolbox Team 2011, 2012
%
% Notes:
%
% The coefficients are from their Table 1.  We think these are the OSA
% coefficients.  They provide 14 coefficients, which we think go into our
% zcoeefs 1-13.  That's because they label the first coefficient as 0 and
% we ignore that.
%
% When I asked her what her best guess was, Heidi wrote:
%   The code and coefficients I provided were set up to use Zernike
%   coefficients expressed based on the OSA standards.  I am assuming
%   Larry Thibos would only be using coefficients also expressed according
%   to the OSA standards (especially since he had a role in developing the
%   standards), but I couldn't find a statement to that fact in their
%   paper.  I am also slightly confused that they would keep the 0,1, and
%   2 terms for the standard observer since the 0 terms should be a piston
%   term (and I'm not aware of a way to measure this meaningfully) and the
%   1 and 2 terms should be tip and tilt, which only impact image quality
%   by translating the PSF (and are difficult to measure in a meaningful
%   way).
%
% The coefficients are for a 6 mm measured pupil.  I think Figure 11 is
% computed for a 6 mm pupil as well, but that isn't quite so clear.  (The
% functions for EES in Figure 11 look a lot like those in Figure 10, and
% Figure 10 is for a 6 mm pupil.)

%% Clear your work space
clear; close all;

%% Or reinitialize ISET.  Different people do different things
s_initISET

%% Read in coefficients of Autrusseau standard observer and set up wvf

% Load 'em up
autStandardObsZcoeffs = load('autrusseauStandardObserver.txt');
zcoeffs = zeros(65,1);
zcoeffs(1:13) = autStandardObsZcoeffs(2:14);

% Place them
wvfStandardObs = wvfCreate;                                 % Initialize
wvfStandardObs = wvfSet(wvfStandardObs,'zcoeffs',zcoeffs);  % Zernike
wvfStandardObs = wvfSet(wvfStandardObs,'measuredpupil',6);  % Data
wvfStandardObs = wvfSet(wvfStandardObs,'calculatedpupil',6);% What we calculate

%% Compute the PSF at 550 nm from their data, and look at it.
%
% NOTE.  The plot of PSF gets unhappy if I give it a max scale
% value of much smaller than 20 minutes.  I am not sure why
% it doesn't handle that gracefully.  Probably a failure on
% my part to grok the ISET way (dhb).
wvfStandardObs = wvfComputePSF(wvfStandardObs); 
pupilfuncrangeMM = 6;
psffuncmaxMin = 1/3;
waveIdx = 1;

vcNewGraphWin;
wvfPlot(wvfStandardObs,'2d pupil phase space','mm',waveIdx,pupilfuncrangeMM);

vcNewGraphWin;
wvfPlot(wvfStandardObs,'2d psf angle normalized','deg',waveIdx,psffuncmaxMin);

%% Fails below here.  Let's get the multiple wavelength stuff working.

% Compute the polychromatic PSF
wls = (400:10:700)';
wvfStandardObs = wvfSet(wvfStandardObs,'wavelength',wls);
wvfStandardObs = wvfComputePSF(wvfStandardObs); 
psfSamples = wvfGet(wvfStandardObs,'samples angle','deg',waveIdx);
polyPsf = wvfGet(wvfStandardObs,'psf');

%% End

%% THIS IS STUFF FROM THE TUTORIAL, WHICH I LEFT SO I COULD COPY/PASTE.

%% Use Zernike polynomials to specify a diffraction limited PSF.
%
% Use wvfCreate to create a wavefront variable to explore with.
%
% This wavefront by default has the 0's for all zernike coeffs
% Notice that the calcpupilMM is by default 3, meaning we are simulating
% the wavefront PSF for a pupil of 3MM diameter.  This code dumps
% out the structure so you can get a sense of what is in it.
% 
% The validation script v_wvfDiffractionPSF compares the diffraction
% limited PSFs obtained in this manner with those obtained by
% computing an Airy disk and shows that they match.

% Compute the PSF for this wavefront and store it in the structure.
wvf0 = wvfComputePSF(wvf0);

% Look at the plot of the normalized PSF within 1 mm of the center.
% Variable maxMM is used to specify size of plot from center of the PSF.
%
% The plot shows an airy disk computed from the Zernike polynomials; that
% is representing the diffraction-limited PSF obtained when the Zernike
% coefficients are all zero.
vcNewGraphWin;
maxMM = 1;      
wvfPlot(wvf0,'2dpsf space normalized','mm',maxMM);

%% Examine how the first non-zero Zernike coefficient contributes to the PSF.
% The 3rd term (or 4th term when counting the 0th order constant as in the
% j indexing scheme) is known as astigmatism with axis at 45 degrees.
%
% We start with the default structure , wvf0 created above, and set the
% zcoeff column vector to be a new non-zero vector.
zcoeffs = zeros(65,1);
zcoeffs(3) = 0.75;                              % Just a non-zero weight
wvf3 = wvfSet(wvf0,'zcoeffs',zcoeffs);

% Look at the pupil function for astigmatism with axis at 45 degrees.
%
% We have used wvfComputePupilFunction separately here, but it is actually also
% contained within wvfComputePSF, which we will use from now on.
wvf3 = wvfComputePupilFunction(wvf3);

% Now we plot the pupil function, which captures phase information about
% the wavefront aberrations.
%
% We can see that the phase changes seem to be aligned with the + and - 45
% degree axes. 
pupilfuncrangeMM = 5;
vcNewGraphWin;
wvfPlot(wvf3,'2d pupil phase space','mm',pupilfuncrangeMM);

% While the pupil functions are well specified by Zernike polynomials, it's
% hard to get meaning from them. We'd much prefer to look at the PSF, which
% gives us an idea of how the pupil will blur an image. 
% This is essentially done by applying a Fourier Transform to the pupil
% function.
wvf3 = wvfComputePSF(wvf3); 

% Now we can plot the normalized PSF for a pupil only whose only aberration
% is the 45 degree astigmatism.
%
% As you can see, this no longer looks like the narrower
% diffraction-limited PSF. It has also lost its radial symmetry. We will
% see that the higher the order of Zernike polynomial, the more complex the
% associated PSF will be.
vcNewGraphWin;
maxMM = 2;
wvfPlot(wvf3, '2d psf space normalized','mm',maxMM);

%% Examine effect of  the 5th coeff (j index 6), which is astigmatism
% along the 0 or 90 degree axis.
%
% We can see that unlike the 3rd coefficient, this coefficient for
% astigmatism is aligned to the x and y axes
zcoeffs = zeros(65,1);                            
zcoeffs(5) = 0.75;                              % Just a non-zero weight
wvf5 = wvfSet(wvf0,'zcoeffs',zcoeffs);
wvf5 = wvfComputePSF(wvf5);
vcNewGraphWin;
wvfPlot(wvf5,'2d pupil phase space','mm',3);
vcNewGraphWin;
wvfPlot(wvf5,'2d psf space normalized','mm',maxMM);

%% Go wild and make plots of various pupil functions and their respective
% point-spread functions for different Zernike polynomials of 2nd and 3rd orders
% (j index 3 through 9)
wvf0 = wvfCreate;
wvf0 = wvfSet(wvf0,'calculated pupil',wvfGet(wvf0,'measured pupil','mm'));
pupilfuncrangeMM = 4;
jindices = 3:9;
maxMM = 4; 
for ii = jindices
    vcNewGraphWin;
    zcoeffs = zeros(65,1);
    zcoeffs(ii) = 0.75;
    wvf = wvfSet(wvf0,'zcoeffs',zcoeffs);
    wvf = wvfComputePSF(wvf);

    subplot(2,1,1);
    wvfPlot(wvf,'2d pupil phase space','mm',pupilfuncrangeMM);

    subplot(2,1,2);
    wvfPlot(wvf,'2d psf space','mm',maxMM);
end

%% How longitudinal chromatic aberration (LCA) affects the PSF / "Defocus"
%
% What happens if we want to know how the PSF looks for different wavelengths?
% You may have learned that optical systems can have chromatic aberration,
% where one wavelength is brought into focus but others may be blurry
% because they are refracted closer or farther from the imaging plane. In
% this case, the PSF is dependent on wavelength. 

% We can set this using the  "in-focus wavelength" of our wvf.
% This code indicates that the data is given for a nominal focus of 550 nm,
% which is also the default in wvfCreate.  We also now explictly set the
% wavelength for which the PSF is calculated to 550 nm (this is also the
% default.  
wvf0 = wvfCreate;
wvf0 = wvfSet(wvf0,'nominalfocuswl',550); 
wvf0 = wvfSet(wvf0,'wavelength',550); 

% It turns out that all aberrations other than "Defocus" are known
% to vary only slightly with wavelength. As a result, the Zernike
% coefficients don't have to be modified, apart from one.
% zcoeff(4) is the "Defocus" of a pupil function. It is what typical eyeglasses
% correct for using + or - diopters lenses. The wavefront toolbox combines
% the longitudinal chromatic aberration (LCA) into this coefficient.
wvf0 = wvfComputePSF(wvf0);
vcNewGraphWin;
maxMM = 3; 
wvfPlot(wvf0,'1dpsfspacenormalized','mm',maxMM);
hold on;

% Keep the calculated wavelength at default 550 nm but change
% the nominal in-focus wavelength, then add to the plot.
%
% The new psf is wider due to longitudinal chromatic aberration, even though
% it's still just the diffraction-limited wavefront function (the Zernike
% coefficients are still 0).%
%
% To put it another way, the code produces the
% PSF at the specified wavelengths (set explicitly to just 550 above) given
% that the wavelength of nominal focus is as specified.  Since the two differ
% here, we see the effect of LCA.
wvf1 = wvfCreate;
wvf1 = wvfSet(wvf1,'nominalfocuswl',600); %sets nominal wavelength to 600nm
wvf1 = wvfComputePSF(wvf1);
wvfPlot(wvf1,'1dpsfspacenormalized','mm',maxMM);

%% Verify that The LCA effect is contained solely within the Defocus
% coefficient.
%
% First we explicitly computethe defocus implied by the wavelength difference above.
% Function wvfGetDefocusFromWavelengthDifference takes in a wavefront which
% contains information about the specified nominal wavelength and calculated
% wavelength. It computes the defocus in diopters from using unmatched wavelengths, 
% and returns the defocus converted into microns. This is important because Zernike
% coefficients are assumed to be given in microns.
defocusMicrons = wvfGetDefocusFromWavelengthDifference(wvf1);

% Make a new wavefront which does not have the mismatched wavelengths.
% Because these both default to 550 nm, they match here.
wvf2 = wvfCreate;
nominalWl = wvfGet(wvf2,'nominalfocuswl')
calcWl = wvfGet(wvf2,'wavelength')

% Make our adjustment purely to the j=4 Zernike
% coefficient (you may remember from our earlier plotting that this term on
% its own has a radially symmetric PSF which widens the diffraction limited
% PSF). We'll plot this PSF with a thinner blue line and overlay it.
%
% % The two aberrated plots are identical. The defocus of a pupil can be
% measured separately, whether using Zernike coeffs or in diopters, but any
% chromatic aberration is added solely into this coefficient.
zcoeffs = zeros(65,1);
zcoeffs(4) = defocusMicrons;
wvf2 = wvfSet(wvf2,'zcoeffs',zcoeffs);
wvf2 = wvfComputePSF(wvf2);
[udataS, pData] = wvfPlot(wvf2,'1dpsfspacenormalized','mm',maxMM);
set(pData,'color','b','linewidth',2);

%%  How cone geometry affects the PSF: the Stiles-Crawford effect (SCE)
%
% The cones that line our retinas are tall rod-shaped cells. They act like
% waveguides, such that rays parallel to their long axis excite the photoreceptors
% more readily than rays that are travelling at skewed angles. This has the
% benefit of reducing the chance that scattered or aberrated rays will
% excite the cone cells. Although this effect physically comes from the
% retina, it can be modeled using the pupil function discussed above. The
% amplitude of the pupil function is altered, such that it decays in the
% form exp(-alpha*((x-x0)^2+(y-y0)^2)). This physically attenuates rays
% that enter near the edges of the pupil and lens. Since the phase aberration at
% the edges of the pupil is usually most severe, SCE can actually improve vision. 
% Note that generally the position of the pupil with highest transmission 
% efficiency does not lie in the exact center of the pupil (x0,y0 are nonzero).

% Begin with an unaberrated pupil and see what its amplitude and phase look
% like. We'll also plot the associated diffraction-limited PSF.
wvf0 = wvfCreate;
wvf0 = wvfComputePSF(wvf0);
maxMM = 2; %MM from the center of the PSF
pupilfuncrangeMM = 5;
vcNewGraphWin;
subplot(2,2,1);
wvfPlot(wvf0,'2d pupil amplitude space','mm',pupilfuncrangeMM);
subplot(2,2,2);
wvfPlot(wvf0,'2d pupil phase space','mm',pupilfuncrangeMM);
subplot(2,2,3:4);
wvfPlot(wvf0,'2d psf space','mm',maxMM);

% To this unaberrated pupil function, we add the Stiles-Crawford
% parameters, as measured by Berendshot et al. (see sceCreate for
% details). This adds a decaying exponential amplitude to the pupil
% function, causing less light to be transmitted to the retina.
%
% Compare the diffraction-limited PSF without SCE to the one with SCE. What
% are the differences? Is the amplitude different? Why? Is the width of the
% PSF different? Why?
wvf0SCE = wvfSet(wvf0,'sceParams',sceCreate(wvfGet(wvf0,'wave'),'berendshot'));
wvf0SCE = wvfComputePSF(wvf0SCE);
vcNewGraphWin;
subplot(2,2,1);
wvfPlot(wvf0SCE,'2d pupil amplitude space','mm',pupilfuncrangeMM);
subplot(2,2,2);
wvfPlot(wvf0SCE,'2d pupil phase space','mm',pupilfuncrangeMM);
subplot(2,2,3:4);
wvfPlot(wvf0SCE,'2d psf space','mm',maxMM);

% Compare the above with how the SCE affects an aberrated PSF. Let's create a
% PSF with moderate astigmatism along the xy axes.
zcoeffs = zeros(65,1);
zcoeffs(5) = 0.75;
wvf5 = wvfSet(wvf0,'zcoeffs',zcoeffs);
wvf5 = wvfComputePSF(wvf5);
vcNewGraphWin;
subplot(2,2,1);
wvfPlot(wvf5,'2d pupil amplitude space','mm',pupilfuncrangeMM);
subplot(2,2,2);
wvfPlot(wvf5,'2d pupil phase space','mm',pupilfuncrangeMM);
subplot(2,2,3:4);
wvfPlot(wvf5,'2d psf space','mm',maxMM);

% Add SCE to the aberrated pupil function.
%
% Compare the two aberrated PSFs. How do their peak amplitudes compare?
% How do their widths compare? How did the symmetry of the PSF change?
% Which PSF would create a "better image" on the retina?
wvf5SCE = wvfSet(wvf5,'sceParams',sceCreate(wvfGet(wvf5,'wave'),'berendshot'));
wvf5SCE = wvfComputePSF(wvf5SCE);
vcNewGraphWin;
subplot(2,2,1);
wvfPlot(wvf5SCE,'2d pupil amplitude space','mm',pupilfuncrangeMM);
subplot(2,2,2);
wvfPlot(wvf5SCE,'2d pupil phase space','mm',pupilfuncrangeMM);
subplot(2,2,3:4);
wvfPlot(wvf5SCE,'2d psf space','mm',maxMM);

%% Wavefront measurements of human eyes and the effects of single-vision
% corrective eyeglasses 
%
% We have access to measurements of the pupil function of real human eyes. The
% optics of these eyes are not perfect, so they have interesting pupil functions
% and PSF shapes.

% Set up the wvf structure
measMM = 6;
calcMM = 3;
maxMM = 3;
theWavelengthNM = 550;
wvfHuman0 = wvfCreate('measured pupil',measMM,'calculated pupil',calcMM);
wvfHuman0 = wvfSet(wvfHuman0,'wavelength',theWavelengthNM);

% Load in some measured data
sDataFile = fullfile(wvfRootPath,'data','sampleZernikeCoeffs.txt');
theZernikeCoeffs = load(sDataFile);
whichSubjects = [3 7];
theZernikeCoeffs = theZernikeCoeffs(:,whichSubjects);
nSubjects = size(theZernikeCoeffs,2);
nRows = ceil(sqrt(nSubjects));
nCols = ceil(nSubjects/nRows);

% Stiles Crawford
wvfHuman0 = wvfSet(wvfHuman0,'sceParams',sceCreate(wvfGet(wvfHuman0,'wave'),'berendshot'));

% Plot subject PSFs, one by one
for ii = 1:nSubjects
    fprintf('** Subject %d\n',whichSubjects(ii))

    wvfHuman = wvfSet(wvfHuman0,'zcoeffs',theZernikeCoeffs(:,ii));
    wvfHuman = wvfComputePSF(wvfHuman);
    
    vcNewGraphWin;
    subplot(2,2,1);
    wvfPlot(wvfHuman,'2d pupil amplitude space','mm',calcMM);
    subplot(2,2,2);
    wvfPlot(wvfHuman,'2d pupil phase space','mm',calcMM);
    subplot(2,2,3:4);
    wvfPlot(wvfHuman,'2d psf space','mm',maxMM);
end

%% Single-vision eyewear generally corrects only the lowest-order
% Zernike aberrations (defocus given in diopters) and astigmatism (cylinder
% correction also given in diopters). The Zernike coefficients give us an
% easy and convenient way to simulate corrective lenses; we can simply set
% those Zernike coefficients to zero and see what the PSFs look like!
%
% Plot their corrected PSFs, one by one, How do the corrected PSFs compare
% to the uncorrected ones? their peaks? their widths?
%
% Try changing the whichSubjects array above to look at other sample data. Do
% eyeglasses help correct the aberrations in those subjects?
%
% If you were to spend thousands of dollars on laser eye surgery, would you
% want them to only correct the first order of wavefront aberrations, like
% eyeglasses, or do a full wavefront measurement?
% 
% Suppose you knew that such surgery would correct some of the lower order aberrations but some of the
% higher order aberrations worse.  How would you compute the net effect of
% something like that?
for ii = 1:nSubjects
    fprintf('** Subject %d corrected\n',whichSubjects(ii))
    
    % Correct defocus and astigmatism
    zCoeffs = theZernikeCoeffs(:,ii);
    zCoeffs(3:5) = 0;
    wvfHuman = wvfSet(wvfHuman0,'zcoeffs',zCoeffs);
    wvfHuman = wvfComputePSF(wvfHuman);
    
    vcNewGraphWin;
    subplot(2,2,1);
    wvfPlot(wvfHuman,'2d pupil amplitude space','mm',calcMM);
    subplot(2,2,2);
    wvfPlot(wvfHuman,'2d pupil phase space','mm',calcMM);
    subplot(2,2,3:4);
    wvfPlot(wvfHuman,'2d psf space','mm',maxMM);
end



