function lcaDiopters = wvfLCAFromWavelengthDifference(wl1NM,wl2NM)
% lcaDiopters = wvfLCAFromWavelengthDifference(wl1NM,wl2NM)
%
% Longitudinal chromatic aberration (LCA), expressed in diopters, between
% two wavelengths.
%
% If the image is in focus at wl1NM, add the answer to bring it into focus at
% wl2NM.
%
% Either input argument may be a vector, but if both are vectors they need
% to have the same dimensions.
%
% Note from DHB.  This magic code provided by Heidi Hofer. It does have the
% feature that the adjustment is 0 when the wavelength being evaluated
% matches the passed nominal focus wavelength.  Heidi assures me that the
% constants are correct for any pair of wavelengths.
%
% 8/21/11  dhb  Pulled out from code supplied by Heidi Hofer.
% 9/5/11   dhb  Rename.  Rewrite for wvfPrams i/o.
% 5/29/12  dhb  Pulled out just the bit tah
%
% (c) Wavefront Toolbox Team 2011


% Here's the magic
constant = 1.8859 - (0.63346/(0.001*wl1NM-0.2141));
lcaDiopters = 1.8859 - constant - (0.63346/(0.001*wl2NM-0.2141));  

return
