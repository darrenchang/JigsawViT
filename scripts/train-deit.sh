# !/bin/bash

script_dir=$(dirname "$0")
(
    cd $script_dir/../imagenet/jigsaw-deit;
    python3 -m torch.distributed.launch \
    --nproc_per_node=1 \
    --use_env \
    main_jigsaw.py \
    --model jigsaw_base_patch16_224 \
    --batch-size 64 \
    --data-path /vit/jigsaw-dataset/ \
    --lambda-jigsaw 0.1 \
    --mask-ratio 0.5 \
    --output_dir /vit/jigsaw-output
)
