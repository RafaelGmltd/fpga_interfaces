import math
from fixedpoint import FixedPoint

def crc_8(bytearr):
    generator = 0x9b
    crc = 0
    for byte in bytearr:
        crc = crc ^ byte
        for i in range(0, 8):
            if ((crc >> 7) & 0xFF):
                crc = ((crc << 1) & 0xFF) ^ generator
            else:
                crc = ((crc << 1) & 0xFF)
    return crc

# Input angle in degrees
angle = input("Enter angle in degrees: ")
# Convert to radians
angle_rad = float(angle) * math.pi / 180.0
print("\nAngle in radians: ", angle_rad)
# Convert to FixedPoint (48 bits: 4 integer, 44 fractional)
angle_fixed = FixedPoint(angle_rad, signed=True, m=4, n=44)
print("\nAngle in hex signed: ", angle_fixed)
# Create empty bytearray
packet = bytearray()
# Append three bytes
packet.append(0x5a)  
packet.append(0xd1)  
for i in reversed(range(0,6)):
    packet.append(int(str(angle_fixed)[(i*2):(i*2)+2], 16))
# CRC
packet.append(crc_8(packet))

print("\nHEADER CMD ANGLE(6 bytes) CRC:", ' '.join(f'{b:02X}' for b in packet))
