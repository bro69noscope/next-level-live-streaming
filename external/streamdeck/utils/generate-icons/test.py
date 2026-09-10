from constants import SDECK_MANIFEST_FILENAMES, VCDATA_SDECK_ROOT
from resolve_outpath import resolve_profile_switch_images_dirs

manifest_filename = SDECK_MANIFEST_FILENAMES[VCDATA_SDECK_ROOT]
result = resolve_profile_switch_images_dirs(
    "profile_aoe2_4x8", VCDATA_SDECK_ROOT, manifest_filename
)
print(result)
