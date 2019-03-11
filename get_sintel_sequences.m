% return list of sequences with each row: sequence name, path to frame pngs, path to flow files
function seqs = get_sintel_sequences()
    seqs = strings(1, 3);
    seqs(1, 1) = 'alley_1';
    seqs(1, 2) = 'sintel/training/final/alley_1';
    seqs(1, 3) = 'sintel/training/flow/alley_1';
end
