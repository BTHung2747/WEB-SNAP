"""Native video admission only; no scaling or transcoding."""
def full_hd(width,height):
    return (type(width) is int and type(height) is int and width>0 and height>0
            and min(width,height)<=1080 and max(width,height)<=1920)
