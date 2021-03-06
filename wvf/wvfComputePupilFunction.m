function wvf = wvfComputePupilFunction(wvf)
% wvf = wvfComputePupilFunction(wvf)
%
% Compute the pupil fuction given the wvf object.  If the function is already
% computed and not stale, this will return fast.  Otherwise it computes and
% stores.
%
% The pupil function is a complex number that represents the amplitude and
% phase of the wavefront across the pupil.  The returned pupil function at
% a specific wavelength is
%
%    pupilF = A exp(-1i 2 pi (phase/wavelength));
%
% The amplitude is calculated entirely based on the assumed properties of
% the Stiles-Crawford effect.
%
% The pupil function is related to the PSF by the Fourier transform. See J.
% Goodman, Intro to Fourier Optics, 3rd ed, p. 131. (MDL)
%
% These functions are calculated for 10 orders of Zernike coeffcients specified to
% the OSA standard. Includes SCE (Stiles-Crawford Effect) if specified.
% The SCE is modeled as an apodization filter (a spatially-varying amplitude
% attenuation) to the pupil function. In this case, it is a decaying exponential.
%
% Transverse chromatic aberration (TCA), which is a wavelength dependent tip
% or tilt, has also not been included.
%
% See also: wvfCreate, wvfGet, wfvSet, wvfComputePSF
%
% Original code provided by Heidi Hofer.
%
% 8/20/11 dhb      Rename function and pull out of supplied routine.
%                  Reformat comments.
% 9/5/11  dhb      Rewrite for wvf struct i/o.  Rename.
% 5/29/12 dhb      Removed comments about old inputs, since this now gets
%                  its data via wvfGet.
% 6/4/12  dhb      Implement caching system.
%
% (c) Wavefront Toolbox Team 2011, 2012

%% Parameter checking
if ieNotDefined('wvf'), error('wvf required'); end

% Only do this if we need to. It might already be computed
if (~isfield(wvf,'pupilfunc') || ~isfield(wvf,'PUPILFUNCTION_STALE') || wvf.PUPILFUNCTION_STALE) 
    % Make sure calculation pupil size is less than or equal measured size
    calcPupilSizeMM = wvfGet(wvf,'calc pupil size','mm');
    measPupilSizeMM = wvfGet(wvf,'measured pupil size','mm');
    if (calcPupilSizeMM > measPupilSizeMM)
        error('Calculation pupil (%.2f mm) must not exceed measurement pupil (%.2f mm).', ...
            calcPupilSizeMM, measPupilSizeMM);
    end
    
    %% Handle case where not all 65 coefficients are available.
    % As ugly as it is, hard coding 65 here is probably OK, because
    % the actual Zernike expansion below is handled in 65 explicit
    % steps and isn't going to change easily.
    c = zeros(65,1);
    c(1:length(wvfGet(wvf,'zcoeffs'))) = wvfGet(wvf,'zcoeffs');
    
    %% Handle defocus relative to reference wavelength.
    %
    % The explicit defocus correction is expressed as the difference in diopters between
    % the defocus correction at measurement time and the defocus correction we're calculating for.
    % This models lenses external to the observer's eye, which affect focus but
    % not the accommodative state.
    defocusCorrectionDiopters = wvfGet(wvf,'calc observer focus correction') - wvfGet(wvf,'measured observer focus correction');
    defocusCorrectionMicrons = defocusCorrectionDiopters * (measPupilSizeMM )^2/(16*sqrt(3));
    
    %% Convert wavelengths in nanometers to wavelengths in microns
    waveUM = wvfGet(wvf,'calc wavelengths','um');
    waveNM = wvfGet(wvf,'calc wavelengths','nm');
    nWavelengths = wvfGet(wvf,'number calc wavelengths');
    
    %% Compute the pupil function
    %
    % This needs to be done separate at each wavelength because
    % the size in the pupil plane that we sample can be wavelength
    % dependent.
    wBar = waitbar(0,'Computing pupil functions');
    pupilfunc = cell(nWavelengths,1);
    for ii=1:nWavelengths
        thisWave = waveNM(ii);
        waitbar(ii/nWavelengths,wBar,sprintf('Pupil function for %.0f',thisWave));
        
        % Set SCE correction params, if desired
        xo  = wvfGet(wvf,'scex0');
        yo  = wvfGet(wvf,'scey0');
        rho = wvfGet(wvf,'sce rho');
        
        % Set up pupil coordinates
        nPixels = wvfGet(wvf,'spatial samples');
        pupilPlaneSizeMM = wvfGet(wvf,'pupil plane size','mm',ii);
        pupilPos = (0:(nPixels-1))*(pupilPlaneSizeMM/nPixels)-pupilPlaneSizeMM/2;
        [xpos ypos] = meshgrid(pupilPos);
        
        % Set up the amplitude of the pupil function.
        % This appears to depend entirely on the SCE correction.  For
        % x,y positions within the pupil, rho is used to set the pupil
        % function amplitude.
        if all(rho) == 0, A = ones(nPixels,nPixels);
        else
            % Get the wavelength-specific value of rho for the Stiles-Crawford
            % effect.
            rho = wvfGet(wvf,'sce rho',thisWave);
            
            % For the x,y positions within the pupil, the value of rho is used to
            % set the amplitude.  I guess this is where the SCE stuff matters.  We
            % should have a way to expose this for teaching and in the code.
            
            % 3/9/2012, MDL: Removed nested for loop for calculating the
            % SCE. Note previous code had x as rows of matrix, y as columns of
            % matrix. This has been corrected so that x is columns, y is rows.
            A = 10.^(-rho*((xpos-xo).^2+(ypos-yo).^2));
        end
        
        % Compute LCA relative to measurement wavelength and then convert to microns so that
        % we can add this in to the wavefront aberrations.
        lcaDiopters = wvfLCAFromWavelengthDifference(wvfGet(wvf,'measured wavelength','nm'),thisWave);
        lcaMicrons = wvfDefocusDioptersToMicrons(lcaDiopters,measPupilSizeMM);
        
        % The Zernike polynomials are defined over the unit disk.  At
        % measurement time, the pupil was mapped onto the unit disk, so we
        % do the same normalization here to obtain the expansion over the disk.
        %
        % And by convention expanding gives us the wavefront aberrations in
        % microns.
        %
        % Note that piston, tilt, and tip do not appear in the expansion below.
        norm_radius = (sqrt(xpos.^2+ypos.^2))/(measPupilSizeMM/2);
        theta = atan2(ypos,xpos);
        wavefrontAberrationsUM = 0 + ...
            c(5) .* sqrt(6).*norm_radius.^2 .* cos(2 .* theta) + ...
            c(3) .* sqrt(6).*norm_radius.^2 .* sin(2 .* theta) + ...
            (c(4)+lcaMicrons+defocusCorrectionMicrons) .* sqrt(3).*(2 .* norm_radius.^2 - 1) + ...
            c(9) .*sqrt(8).* norm_radius.^3 .* cos(3 .* theta) + ...
            c(6) .*sqrt(8).* norm_radius.^3 .* sin(3 .* theta) + ...
            c(8) .*sqrt(8).* (3 .* norm_radius.^3 - 2 .* norm_radius) .* cos(theta) + ...
            c(7) .*sqrt(8).* (3 .* norm_radius.^3 - 2 .* norm_radius) .* sin(theta) + ...
            c(14) .* sqrt(10).*norm_radius.^4 .* cos(4 .* theta) + ...
            c(10) .* sqrt(10).*norm_radius.^4 .* sin(4 .* theta) + ...
            c(13) .* sqrt(10).*(4 .* norm_radius.^4 - 3 .* norm_radius.^2) .* cos(2 .* theta) + ...
            c(11) .* sqrt(10).*(4 .* norm_radius.^4 - 3 .* norm_radius.^2) .* sin(2 .* theta) + ...
            c(12) .* sqrt(5).*(6 .* norm_radius.^4 - 6 .* norm_radius.^2 + 1)+...
            c(20) .* 2.*sqrt(3).*norm_radius.^5 .* cos(5 .* theta) + ...
            c(15) .*2.*sqrt(3).* norm_radius.^5 .* sin(5 .* theta) + ...
            c(19) .* 2.*sqrt(3).*(5 .* norm_radius.^5 - 4 .* norm_radius.^3) .* cos(3 .* theta) + ...
            c(16) .*2.*sqrt(3).* (5 .* norm_radius.^5 - 4 .* norm_radius.^3) .* sin(3 .* theta) + ...
            c(18) .*2.*sqrt(3).* (10 .* norm_radius.^5 - 12 .* norm_radius.^3 + 3 .* norm_radius) .* cos(theta) + ...
            c(17) .*2.*sqrt(3).* (10 .* norm_radius.^5 - 12 .* norm_radius.^3 + 3 .* norm_radius) .* sin(theta) + ...
            c(27) .*sqrt(14).* norm_radius.^6 .* cos(6 .* theta) + ...
            c(21) .*sqrt(14).*norm_radius.^6 .* sin(6 .* theta) + ...
            c(26) .*sqrt(14).*(6 .* norm_radius.^6 - 5 .* norm_radius.^4) .* cos(4 .* theta) + ...
            c(22) .*sqrt(14).*(6 .* norm_radius.^6 - 5 .* norm_radius.^4) .* sin(4 .* theta) + ...
            c(25) .*sqrt(14).* (15 .* norm_radius.^6 - 20 .* norm_radius.^4 + 6 .* norm_radius.^2) .* cos(2 .* theta) + ...
            c(23) .*sqrt(14).*(15 .* norm_radius.^6 - 20 .* norm_radius.^4 + 6 .* norm_radius.^2) .* sin(2 .* theta) + ...
            c(24) .*sqrt(7).* (20 .* norm_radius.^6 - 30 .* norm_radius.^4 + 12 .* norm_radius.^2 - 1)+...
            c(35) .*4.* norm_radius.^7 .* cos(7 .* theta) + ...
            c(28) .*4.* norm_radius.^7 .* sin(7 .* theta) + ...
            c(34) .*4.* (7 .* norm_radius.^7 - 6 .* norm_radius.^5) .* cos(5 .* theta) + ...
            c(29) .*4.* (7 .* norm_radius.^7 - 6 .* norm_radius.^5) .* sin(5 .* theta) + ...
            c(33) .*4.* (21 .* norm_radius.^7 - 30 .* norm_radius.^5 + 10 .* norm_radius.^3) .* cos(3 .* theta) + ...
            c(30) .*4.* (21 .* norm_radius.^7 - 30 .* norm_radius.^5 + 10 .* norm_radius.^3) .* sin(3 .* theta) + ...
            c(32) .*4.* (35 .* norm_radius.^7 - 60 .* norm_radius.^5 + 30 .* norm_radius.^3 - 4 .* norm_radius) .* cos(theta) + ...
            c(31) .*4.* (35 .* norm_radius.^7 - 60 .* norm_radius.^5 + 30 .* norm_radius.^3 - 4 .* norm_radius) .* sin(theta) +...
            c(44) .*sqrt(18).* norm_radius.^8 .* cos(8 .* theta) + ...
            c(36) .*sqrt(18).* norm_radius.^8 .* sin(8 .* theta) + ...
            c(43) .*sqrt(18).* (8 .* norm_radius.^8 - 7 .* norm_radius.^6) .* cos(6 .* theta) + ...
            c(37) .*sqrt(18).* (8 .* norm_radius.^8 - 7 .* norm_radius.^6) .* sin(6 .* theta) + ...
            c(42) .*sqrt(18).* (28 .* norm_radius.^8 - 42 .* norm_radius.^6 + 15 .* norm_radius.^4) .* cos(4 .* theta) + ...
            c(38) .*sqrt(18).* (28 .* norm_radius.^8 - 42 .* norm_radius.^6 + 15 .* norm_radius.^4) .* sin(4 .* theta) + ...
            c(41) .*sqrt(18).* (56 .* norm_radius.^8 - 105 .* norm_radius.^6 + 60 .* norm_radius.^4 - 10 .* norm_radius.^2) .* cos(2 .* theta) + ...
            c(39) .*sqrt(18).* (56 .* norm_radius.^8 - 105 .* norm_radius.^6 + 60 .* norm_radius.^4 - 10 .* norm_radius.^2) .* sin(2 .* theta) + ...
            c(40) .*3.* (70 .* norm_radius.^8 - 140 .* norm_radius.^6 + 90 .* norm_radius.^4 - 20 .* norm_radius.^2 + 1) + ...
            c(54) .*sqrt(20).* norm_radius.^9 .* cos(9 .* theta) + ...
            c(45) .*sqrt(20).* norm_radius.^9 .* sin(9 .* theta) + ...
            c(53) .*sqrt(20).* (9 .* norm_radius.^9 - 8 .* norm_radius.^7) .* cos(7 .* theta) + ...
            c(46) .*sqrt(20).* (9 .* norm_radius.^9 - 8 .* norm_radius.^7) .* sin(7 .* theta) + ...
            c(52) .*sqrt(20).* (36 .* norm_radius.^9 - 56 .* norm_radius.^7 + 21 .* norm_radius.^5) .* cos(5 .* theta) + ...
            c(47) .*sqrt(20).* (36 .* norm_radius.^9 - 56 .* norm_radius.^7 + 21 .* norm_radius.^5) .* sin(5 .* theta) + ...
            c(51) .*sqrt(20).* (84 .* norm_radius.^9 - 168 .* norm_radius.^7 + 105 .* norm_radius.^5 - 20 .* norm_radius.^3) .* cos(3 .* theta) + ...
            c(48) .*sqrt(20).* (84 .* norm_radius.^9 - 168 .* norm_radius.^7 + 105 .* norm_radius.^5 - 20 .* norm_radius.^3) .* sin(3 .* theta) + ...
            c(50) .*sqrt(20).* (126 .* norm_radius.^9 - 280 .* norm_radius.^7 + 210 .* norm_radius.^5 - 60 .* norm_radius.^3 + 5 .* norm_radius) .* cos(theta) + ...
            c(49) .*sqrt(20).* (126 .* norm_radius.^9 - 280 .* norm_radius.^7 + 210 .* norm_radius.^5 - 60 .* norm_radius.^3 + 5 .* norm_radius) .* sin(theta) + ...
            c(65) .*sqrt(22).* norm_radius.^10 .* cos(10 .* theta) + ...
            c(55) .*sqrt(22).* norm_radius.^10 .* sin(10 .* theta) + ...
            c(64) .*sqrt(22).* (10 .* norm_radius.^10 - 9 .* norm_radius.^8) .* cos(8 .* theta) + ...
            c(56) .*sqrt(22).* (10 .* norm_radius.^10 - 9 .* norm_radius.^8) .* sin(8 .* theta) + ...
            c(63) .*sqrt(22).* (45 .* norm_radius.^10 - 72 .* norm_radius.^8 + 28 .* norm_radius.^6) .* cos(6 .* theta) + ...
            c(57) .*sqrt(22).* (45 .* norm_radius.^10 - 72 .* norm_radius.^8 + 28 .* norm_radius.^6) .* sin(6 .* theta) + ...
            c(62) .*sqrt(22).* (120 .* norm_radius.^10 - 252 .* norm_radius.^8 + 168 .* norm_radius.^6 - 35 .* norm_radius.^4) .* cos(4 .* theta) + ...
            c(58) .*sqrt(22).* (120 .* norm_radius.^10 - 252 .* norm_radius.^8 + 168 .* norm_radius.^6 - 35 .* norm_radius.^4) .* sin(4 .* theta) + ...
            c(61) .*sqrt(22).* (210 .* norm_radius.^10 - 504 .* norm_radius.^8 + 420 .* norm_radius.^6 - 140 .* norm_radius.^4 + 15 .* norm_radius.^2) .* cos(2 .* theta) + ...
            c(59) .*sqrt(22).* (210 .* norm_radius.^10 - 504 .* norm_radius.^8 + 420 .* norm_radius.^6 - 140 .* norm_radius.^4 + 15 .* norm_radius.^2) .* sin(2 .* theta) + ...
            c(60) .*sqrt(11).* (252 .* norm_radius.^10 - 630 .* norm_radius.^8 + 560 .* norm_radius.^6 - 210 .* norm_radius.^4 + 30 .* norm_radius.^2 - 1);
        
        % Here is the pupil function
        pupilfunc{ii} = A.*exp(-1i * 2 * pi * wavefrontAberrationsUM/waveUM(ii));
        
        % Set values outside the pupil we're calculating for to 0
        pupilfunc{ii}(norm_radius > calcPupilSizeMM/measPupilSizeMM)=0;
        
        % Attach the function the the proper wavelength slot
        %wvf = wvfSet(wvf,'pupilfunc',pupilfunc,ii);
    end
    close(wBar)
    
    wvf.pupilfunc = pupilfunc;
    wvf.PUPILFUNCTION_STALE = false;
    wvf.PSF_STALE = true;
    
end

end

