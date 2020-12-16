#include <stdio.h>
#include <stdlib.h>
#include <dirent.h> 
#include <string.h>
#include <sys/stat.h> 
#include <sys/types.h> 
#include <math.h>
#include <omp.h>

double results[10000];

double calculateDet(double* a, int n) {
   int i = 0, j = 0, k = 0;
   double* l = (double*) malloc(n*n*sizeof(double));
   double* u = (double*) malloc(n*n*sizeof(double));
   double det = 1.0;
   for (i = 0; i < n; i++) {
      for (j = 0; j < n; j++) {
         if (j < i)
         l[j*n+i] = 0;
         else {
            l[j*n+i] = a[j*n+i];
            for (k = 0; k < i; k++) {
               l[j*n+i] = l[j*n+i] - l[j*n+k] * u[k*n+i];
            }
         }
      }
      for (j = 0; j < n; j++) {
         if (j < i)
         u[i*n+j] = 0;
         else if (j == i)
         u[i*n+j] = 1;
         else {
            u[i*n+j] = a[i*n+j] / l[i*n+i];
            for (k = 0; k < i; k++) {
               u[i*n+j] = u[i*n+j] - ((l[i*n+k] * u[k*n+j]) / l[i*n+i]);
            }
         }
      }
   }
   for (i = 0; i < n; i++) {
      det *= l[i*n+i];
   }
   return det;
}

void detTask(double* a, int n, int line) {
    double det = calculateDet(a, n);
    results[line] = det;
}

void writeFile(FILE* fpw, int numOfLines) {
    for(int i=0; i<numOfLines; i++)
        fprintf(fpw, "%lf\n", results[i]);
}

void readLine(FILE* fpr, FILE* fpw) {
    char c;
    double buff[500000];
    int index = 0;
    int line = 0;
    while ((c = getc(fpr)) != EOF) {
        if(c == ' ') continue;
        if(c == '\n') { 
            detTask(buff, sqrt(index), line);
            c = getc(fpr);
            index = 0;
            line++;
            continue;
        }
        buff[index] = (double) c - 48.0;
        index++;
    }
    writeFile(fpw, line);
}

void readFile(char* dir, char* fileName) {
    FILE *fpr;
    FILE *fpw;
    fpr = fopen(dir, "r+");
    if (fpr == NULL) {
        perror("fopen()");
    }
    char path[100];
    path[0] = '\0';
    strcat(strcat(path, "./data_out/"), fileName);
    fpw = fopen(path, "w");
    if (fpw == NULL) {
        perror("fopen()");
    }
    readLine(fpr, fpw);
    fclose(fpr);
}

void readDirectory(char* dir) {
    struct dirent *de;
    DIR *dr = opendir(dir); 
    if (dr == NULL) { 
        printf("Could not open current directory" ); 
    } 
    de = readdir(dr);
    de = readdir(dr);
    while ((de = readdir(dr)) != NULL) {
        char path[100];
        path[0] = '\0';
        strcat(strcat(strcat(path, dir), "/"), de->d_name);
        readFile(path, de->d_name);
    }
    closedir(dr); 
}

int main() {
    //mkdir("data_out", 0777);
    double start = omp_get_wtime();
    readDirectory("./data_in");
    printf("%lf\n", omp_get_wtime()-start);
    return 0; 
}