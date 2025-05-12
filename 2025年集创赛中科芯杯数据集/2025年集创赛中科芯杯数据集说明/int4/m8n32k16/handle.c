#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFFER_SIZE 256
#define OUTPUT_FILE "output.txt"

void convertTo32BitHex(FILE *input, FILE *output) {
    unsigned char buffer[BUFFER_SIZE];
    size_t bytesRead;

    while ((bytesRead = fread(buffer, 1, BUFFER_SIZE, input)) > 0) {
        size_t offset = 0;
        while (offset < bytesRead) {
            size_t remaining = bytesRead - offset;
            if (remaining >= 4) {
                fprintf(output, "%02X%02X%02X%02X,",
                        buffer[offset], buffer[offset+1], buffer[offset+2], buffer[offset+3]);
                offset += 4;
            } else {
                char hex[9] = {0};
                for (size_t i = 0; i < remaining; i++) {
                    sprintf(hex + 2 * i, "%02X", buffer[offset + i]);
                }
                for (size_t i = remaining; i < 4; i++) {
                    strcat(hex, "00");
                }
                fprintf(output, "%s,", hex);
                offset += remaining;
            }
        }
        fprintf(output, "\n");
    }
}

int main() {
    FILE *input = fopen("c_int4_m8n32k16.bin", "rb");
    if (input == NULL) {
        printf("Error opening input file!\n");
        return 1;
    }

    FILE *output = fopen(OUTPUT_FILE, "w");
    if (output == NULL) {
        printf("Error opening output file!\n");
        fclose(input);
        return 1;
    }

    convertTo32BitHex(input, output);

    fclose(input);
    fclose(output);
    return 0;
}