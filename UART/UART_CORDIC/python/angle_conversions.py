import math
from fixedpoint import FixedPoint

# Convert hex string to signed integer (2's complement)
def twos_complement(hexstr,bits):    # Hex string and bit width
     value = int(hexstr,16)          # Convert from hex to int
     if value & (1 << (bits-1)):     # Check the sign bit (MSB)
         value -= 1 << bits          # If it's set — subtract 2^bits (standard 2's complement procedure, remember)
     return value

# Input: fractional bits for Q format and signed hex angle
scale = int(input("\nEnter fractional bit count for Q2.scale format (e.g., 46 for Q2.46):  : "))
angle_hex_signed = input("\nEnter angle in HEX format (48-bit signed): ")
# Convert to radians and degrees
angle_rad_int = (twos_complement(str(angle_hex_signed), 48) / (2**scale))
angle_int = (twos_complement(str(angle_hex_signed), 48) / (2**scale)) * 180.0 / math.pi
print("\nAngle in radians: ", angle_rad_int , "rad")
print("\nAngle in degrees: ", angle_int, "°")

# # Convert degrees to fixed-point hex and rad
# angle = input("\nEnter angle (degrees): ")
# angle_rad = float(angle) * math.pi / 180.0 
# angle_rad_fixed = FixedPoint(angle_rad, signed=True, m=4, n=44)  
# print("\nAngle in HEX format (48-bit signed): ", angle_rad_fixed)                                                                                    
# print("\nAngle in radians: ", angle_rad)   
