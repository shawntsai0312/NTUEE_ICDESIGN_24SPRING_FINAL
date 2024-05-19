import csv
pChoice = 2
testData = 3

# Read data from .dat file
with open('../P'+str(pChoice)+'/param.dat', 'r') as f:
    lines = f.readlines()
    data = [line.strip() for line in lines[testData*4:testData*4+4]]

H0 = int(data[0], 16)
V0 = int(data[1], 16)
SW = int(data[2], 16)
SH = int(data[3], 16)

print(H0, V0, SW, SH)

# rom data

# Read data from .dat file
with open('../P'+str(pChoice)+'/rom.dat', 'r') as f:
    romData = [line.strip() for line in f]

# Write data to .csv file
with open('./P'+str(pChoice)+'_' + str(testData) + '_rom.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    romHeader = [hex(i)[2:].zfill(2)
                 for i in range(H0, H0+SW)]  # Convert to hexadecimal
    writer.writerow([''] + romHeader)  # Write the header
    for i in range(V0, V0 + SH):
        romIndex = hex(i)[2:].zfill(2)
        writer.writerow([romIndex] + romData[i*64 + H0:i*64 + H0 + SW])


# golden data
# Prepare the header and index
goldenHeader = [hex(i)[2:].zfill(2)
                for i in range(17)]  # Convert to hexadecimal
goldenIndex = [hex(i)[2:].zfill(2)
               for i in range(17)]  # Convert to hexadecimal

# Read data from .dat file
with open('../P'+str(pChoice)+'/golden.dat', 'r') as f:
    lines = f.readlines()
    goldenData = [line.strip()
                  for line in lines[testData*289:testData*289+289]]

# Write data to .csv file
with open('./P'+str(pChoice)+'_' + str(testData) + '_golden.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow([''] + goldenHeader)  # Write the header
    for i, row in enumerate(range(0, len(goldenData), 17)):
        # Write the index and the row data
        writer.writerow([goldenIndex[i]] + goldenData[row:row+17])
