% return list of sequences with each row: sequence name, path to frame pngs, path to flow files, no of frames
function seqs = get_middlebury_sequences()
    seqs = strings(1, 5);

    seqs(1, 1) = 'Dimetrodon';
    seqs(2, 1) = 'Grove2';
    seqs(3, 1) = 'Grove3';
    seqs(4, 1) = 'Hydrangea';
    seqs(5, 1) = 'RubberWhale';
    seqs(6, 1) = 'Urban2';
    seqs(7, 1) = 'Urban3';
    seqs(8, 1) = 'Venus';

    for seq = 1 : size(seqs, 1)
        seqs(seq, 2) = strcat('middlebury/other-data/', seqs(seq, 1));
        seqs(seq, 3) = strcat('middlebury/other-flow/', seqs(seq, 1));
        seqs(seq, 4) = strcat('middlebury/other-data/occlusions/', seqs(seq, 1));
        seqs(seq, 5) = num2str(numel(dir(strcat(seqs(seq, 2), '/*.png'))));
    end
end
