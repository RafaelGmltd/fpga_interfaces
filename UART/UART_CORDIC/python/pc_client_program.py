import serial
import math
from fixedpoint import FixedPoint
# ------------------------------------------------------------------------------------------------------------------------------------
def twos_complement(hexstr, bits):
    value = int(hexstr, 16)
    if value & (1 << (bits - 1)):
        value -= 1 << bits
    return value
# ------------------------------------------------------------------------------------------------------------------------------------
def crc_8(bytearr):
    generator = 0x9b
    crc = 0
    for byte in bytearr:
        crc = crc ^ byte
        for _ in range(8):
            if (crc >> 7) & 0xFF:
                crc = ((crc << 1) & 0xFF) ^ generator
            else:
                crc = ((crc << 1) & 0xFF)
    return crc
# ------------------------------------------------------------------------------------------------------------------------------------
def main():
    serial_port = 'COM4'
    baud_rate = 3000000
    ser = serial.Serial(serial_port, baud_rate, timeout=3, parity=serial.PARITY_ODD)
    print("\nSuccessfully opened serial port " + str(serial_port) + " with baud rate " + str(baud_rate) + ".")

    print("\nWelcome to the Arty-A7 UART comm program. Have fun interacting with the CORDIC module!")
# ------------------------------------------------------------------------------------------------------------------------------------
    try:
        while True:
            command = input(" \
            1- Single angle \n \
            2- Bursted angles \n \
            Enter command (or Q to quit): ").strip()

            if command.lower() == 'q':
                print("\nExiting program.")
                ser.close()
                return

            try:
                command = int(command)
            except ValueError:
                print("\nInvalid input. Enter 1, 2 or Q to quit.")
                continue

                                               # Single Angle
# ------------------------------------------------------------------------------------------------------------------------------------
            if command == 1:
                # SINGLE ANGLE
                angle = input("\nEnter angle (degrees): ")
                angle_rad = float(angle) * math.pi / 180.0
                angle_rad_fixed = FixedPoint(angle_rad, signed=True, m=4, n=44)

                packet = bytearray()
                packet.append(0x5a)
                packet.append(0xd1)
                for i in reversed(range(6)):
                    packet.append(int(str(angle_rad_fixed)[(i * 2):(i * 2) + 2], 16))
                packet.append(crc_8(packet))

                print("\nSending message: ")
                print("\tHeader: 0x" + format(packet[0], '02x'))
                print("\tCmd:    0x" + format(packet[1], '02x'))
                print("\tTheta:  0x", end="")
                for i in range(6):
                    print(format(packet[i + 2], '02x'), end="")
                angle_in = (twos_complement(str(angle_rad_fixed), 48) / (2 ** 44)) * 180.0 / math.pi
                print(" (" + str(angle_in) + ")")
                print("\tCRC-8:  0x" + format(packet[-1], '02x'))

                ser.write(packet)
                bytes_back = ser.read(15)

                if bytes_back == b'':
                    print("\nTimed out.")
                    continue

                mycos = ''
                mysin = ''
                for i in reversed(range(6)):
                    mycos += format(bytes_back[i + 2], '02x')
                    mysin += format(bytes_back[i + 8], '02x')
                cos_val = twos_complement(mycos, 48) / (2 ** 46)
                sin_val = twos_complement(mysin, 48) / (2 ** 46)

                print("\nReceived message: ")
                print("\tHeader:        0x" + format(bytes_back[0], '02x'))
                print("\tCmd:           0x" + format(bytes_back[1], '02x'))
                print("\tCos(theta):    0x", end="")
                for i in reversed(range(6)):
                    print(format(bytes_back[i + 2], '02x'), end="")
                print(" (" + str(cos_val) + ")")
                print("\tSin(theta):    0x", end="")
                for i in reversed(range(6)):
                    print(format(bytes_back[i + 8], '02x'), end="")
                print(" (" + str(sin_val) + ")")
                print("\tCRC-8:         0x" + format(bytes_back[-1], '02x'))

                if crc_8(bytes_back) == 0:
                    print("\nCRC-8 of received message passes.")
                else:
                    print("\nCRC-8 of received message does not pass.")

                                               # Burst Angle
# ------------------------------------------------------------------------------------------------------------------------------------
            elif command == 2:
                # BURST ANGLES
                try:
                    burst_cnt = int(input("\nEnter burst_cnt (1-8): "))
                    if not (1 <= burst_cnt <= 8):
                        print("Burst count must be between 1 and 8.")
                        continue
                except ValueError:
                    print("Invalid burst count.")
                    continue

                angle_list = []
                for i in range(burst_cnt):
                    angle = input(f"\nEnter angle #{i + 1} (degrees): ")
                    angle_rad = float(angle) * math.pi / 180.0
                    angle_rad_fixed = FixedPoint(angle_rad, signed=True, m=4, n=44)
                    angle_list.append(angle_rad_fixed)

                packet = bytearray()
                packet.append(0x5a)
                packet.append(0xd2)
                packet.append(burst_cnt)
                for angle_fixed in angle_list:
                    for i in reversed(range(6)):
                        packet.append(int(str(angle_fixed)[(i * 2):(i * 2) + 2], 16))
                packet.append(crc_8(packet))

                print("\nSending message: ")
                print("\tHeader:    0x" + format(packet[0], '02x'))
                print("\tCmd:       0x" + format(packet[1], '02x'))
                print("\tBurst cnt: 0x" + format(packet[2], '02x'))
                for j in range(burst_cnt):
                    print(f"\tTheta # {j + 1}:     0x", end="")
                    for i in range(6):
                        print(format(packet[i + 3 + j * 6], '02x'), end="")
                    angle_in = (twos_complement(str(angle_list[j]), 48) / (2 ** 44)) * 180.0 / math.pi
                    print(" (" + str(angle_in) + ")")
                print("\tCRC-8:     0x" + format(packet[-1], '02x'))

                packet_size = 4 + burst_cnt * 12
                ser.write(packet)
                bytes_back = ser.read(packet_size)

                if bytes_back == b'':
                    print("\nTimed out.")
                    continue

                mycos = []
                mysin = []
                for j in range(burst_cnt):
                    cos_str = ''
                    sin_str = ''
                    for i in reversed(range(6)):
                        cos_str += format(bytes_back[i + 3 + 12 * j], '02x')
                        sin_str += format(bytes_back[i + 9 + 12 * j], '02x')
                    mycos.append(cos_str)
                    mysin.append(sin_str)

                cos_val = [twos_complement(val, 48) / (2 ** 46) for val in mycos]
                sin_val = [twos_complement(val, 48) / (2 ** 46) for val in mysin]

                print("\nReceived message: ")
                print("\tHeader:        0x" + format(bytes_back[0], '02x'))
                print("\tCmd:           0x" + format(bytes_back[1], '02x'))
                print("\tBurst cnt:     0x" + format(bytes_back[2], '02x'))

                for j in range(burst_cnt):
                    print(f"\n  Result #{j + 1}:")
                    print("\tCos(theta):    0x", end="")
                    for i in reversed(range(6)):
                        print(format(bytes_back[i + 3 + 12 * j], '02x'), end="")
                    print(" (" + str(cos_val[j]) + ")")
                    print("\tSin(theta):    0x", end="")
                    for i in reversed(range(6)):
                        print(format(bytes_back[i + 9 + 12 * j], '02x'), end="")
                    print(" (" + str(sin_val[j]) + ")")

                print(f"\nCRC-8:         0x" + format(bytes_back[-1], '02x'))

                if crc_8(bytes_back) == 0:
                    print("\nCRC-8 of received message passes.")
                else:
                    print("\nCRC-8 of received message does not pass.")

            else:
                print("\nUnknown command. Enter 1, 2 or Q.")
# ------------------------------------------------------------------------------------------------------------------------------------
    except KeyboardInterrupt:
        print("\nKeyboard interrupt. Closing serial port.")
        ser.close()

if __name__ == "__main__":
    main()
