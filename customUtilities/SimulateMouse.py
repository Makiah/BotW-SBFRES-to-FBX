# Output utilities (no download required :) )
from ctypes import windll, Structure, c_ulong, byref
import time

# Querying mouse position (StackOverflow credit).  My screen goes from 1279 in the x to 799 in the y.  Top left origin.  
class POINT(Structure):
    _fields_ = [("x", c_ulong), ("y", c_ulong)]

def queryMousePosition():
    pt = POINT()
    windll.user32.GetCursorPos(byref(pt))
    return { "x": pt.x, "y": pt.y}


# Clicking in different locations on screen (also from StackOverflow)
def click(x: int, y: int):
    # see http://msdn.microsoft.com/en-us/library/ms646260(VS.85).aspx for details
    windll.user32.SetCursorPos(x, y)
    windll.user32.mouse_event(2, 0, 0, 0, 0)  # left down
    windll.user32.mouse_event(4, 0, 0, 0, 0)  # left up
    time.sleep(0.2)

# Move the cursor to a certain location.
def moveCursorTo(x: int, y: int):
    windll.user32.SetCursorPos(x, y)

if __name__ == "__main__":
    while True:
        click(500, 500)
        time.sleep(4000)