% return list of sequences with each row: sequence name, path to frame pngs, path to flow files, no of frames
function seqs = get_sintel_sequences()
    seqs = strings(1, 5);

    seqs(1, 1) = 'alley_1';
    seqs(2, 1) = 'alley_2';
    seqs(3, 1) = 'ambush_2';
    seqs(4, 1) = 'ambush_4';
    seqs(5, 1) = 'ambush_5';
    seqs(6, 1) = 'ambush_6';
    seqs(7, 1) = 'ambush_7';
    seqs(8, 1) = 'bamboo_1';
    seqs(9, 1) = 'bamboo_2';
    seqs(10, 1) = 'bandage_1';
    seqs(11, 1) = 'bandage_2';
    seqs(12, 1) = 'cave_2';
    seqs(13, 1) = 'cave_4';
    seqs(14, 1) = 'market_2';
    seqs(15, 1) = 'market_5';
    seqs(16, 1) = 'market_6';
    seqs(17, 1) = 'mountain_1';
    seqs(18, 1) = 'shaman_2';
    seqs(19, 1) = 'shaman_3';
    seqs(20, 1) = 'sleeping_1';
    seqs(21, 1) = 'sleeping_2';
    seqs(22, 1) = 'temple_2';
    seqs(23, 1) = 'temple_3';

    for seq = 1 : size(seqs, 1)
        seqs(seq, 2) = strcat('sintel/training/final/', seqs(seq, 1));
        seqs(seq, 3) = strcat('sintel/training/flow/', seqs(seq, 1));
        seqs(seq, 4) = strcat('sintel/training/occlusions/', seqs(seq, 1));
        seqs(seq, 5) = num2str(numel(dir(strcat(seqs(seq, 2), '/*.png'))));
    end
end
