function val = calc_psnr(I, Ihat)
    [rows columns ~] = size(I);

    mseImage = (double(I) - double(Ihat)) .^ 2;

    mse = sum(sum(mseImage)) / (rows * columns);

    % Calculate PSNR (Peak Signal to noise ratio).
    val = 10 * log10( 255^2 / mse);
end
