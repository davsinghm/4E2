function x264_execute(input_file, output_file, crf, ref_frames, sub_me, key_int)
    x264_opts = strcat("no-psy=1:aq-mode=0:ref=", num2str(ref_frames), ":subme=", num2str(sub_me), ":keyint=", num2str(key_int));
    % only keyint x264_opts = strcat("keyint=", num2str(keyint));
    ret_code = system(strcat("cd FFmpeg ", ...
                    "&& ./ffmpeg -y -i ", "../", input_file, " ", ...
                    "-c:v libx264 -crf ", num2str(crf)," -x264opts ", x264_opts, " ", ...
                    "../", output_file));
    if ret_code ~= 0
        error("x264_execute: exit code is: %d", ret_code);
    end
end
