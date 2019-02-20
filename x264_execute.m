function x264_execute(input_file, output_file, crf, bframes_no, ref_frames, key_int)
    %x264_opts = sprintf("no-psy=1:aq-mode=0:ref=%d:subme=%d:keyint=%d", ref_frames, sub_me, key_int);
    x264_opts = sprintf("ref=%d:keyint=%d", ref_frames, key_int);
    ret_code = system(sprintf("./FFmpeg/ffmpeg -y -i %s -c:v libx264 -crf %d -bf %d -x264opts %s %s", input_file, crf, bframes_no, x264_opts, output_file));
    if ret_code ~= 0
        error("ffmpeg exit code is: %d", ret_code);
    end
end
