#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <cuda.h>
#include <stdlib.h>
#include <stdio.h>
#include <windows.h> 
#include <cmath>
#include <iostream>
#include <string.h>
#include <sys/stat.h> 
#include <sys/types.h> 
#include <omp.h>

__global__ void scale(double *a, int size, int index) {
	int i;
	int start = (index*size + index);
	int end = (index*size + size);
	for (i = start + 1; i<end; i++) {
		a[i] = (a[i] / a[start]);
	}
}

__global__ void reduce(double *a, int size, int index) {
	int i;
	int tid = threadIdx.x;
	int start = ((index + tid + 1)*size + index);
	int end = ((index + tid + 1)*size + size);
	for (i = start + 1; i<end; i++) {
		a[i] = a[i] - (a[start] * a[(index*size) + (index + (i - start))]);
	}
}

void gaussianElimination(double* dev_a, int N) {
	int i;
	for (i = 0; i<N; i++) {
		scale << <1, 1 >> >(dev_a, N, i);
		reduce << <1, (N - i - 1) >> >(dev_a, N, i);
	}
}

double calculateDet(double* a, int N) {
	int i, k;
	double* c = (double *) malloc(N*N*sizeof(double));
	double *dev_a, *dev_b, *dev_c;
	double l;
	int threads = ((N*N) - 1);
	cudaMalloc((void**)&dev_a, N*N * sizeof(double));
	cudaMalloc((void**)&dev_b, N*N * sizeof(double));
	cudaMalloc((void**)&dev_c, N*N * sizeof(double));
	cudaMemcpy(dev_a, a, N*N * sizeof(double), cudaMemcpyHostToDevice);
	gaussianElimination(dev_a, N);
	cudaMemcpy(c, dev_a, N*N * sizeof(double), cudaMemcpyDeviceToHost);
	double det = 1.0;
	for (i = 0; i<N; i++) {
		for (k = 0; k<N; k++) {
			if (i >= k) {
				l = c[i*N + k];
				if (i == k) {
					det *= l;
				}
			}
			else l = 0;
		}	
	}
	cudaFree(dev_a);
	cudaFree(dev_b);
	cudaFree(dev_c);
	return det;
}

double* readLine(FILE* fpr, int* n) {
	int i, j = 0;
	const int buffSize = 100000;
	char line[buffSize];
	if (fgets(line, buffSize, fpr) == NULL)
		return NULL;
	(*n) = (int) sqrt((strlen(line) + 1)/2);
	double *a = (double *)malloc((*n)*(*n)*sizeof(double));
	for (i = 0; i < strlen(line); i++) {
		char c = line[i];
		if (c >= 48 && c <= 57) {
			a[j] = c - 48.0;
			j++;
		}
	}
	return a;
}

void pipeline(FILE* fpr, FILE* fpw) {
	double* readMat = NULL;
	double* readyForCalculateMat = NULL;
	double calculatedDet, readyForWriteDet;
	int* prevSize = (int*) malloc(sizeof(int));
	int* nextSize = (int*)malloc(sizeof(int));
	int read = 1, calc = 0, write = 0;
	while (read + calc + write > 0) {
	#pragma omp parallel num_threads(3)
		{
		#pragma omp sections
			{
			#pragma omp section
				{
					if (read > 0) {
						readMat = readLine(fpr, nextSize);
						if (readMat == NULL)
							read = 0;
					}
				}
			#pragma omp section
				{
					if (calc > 0) {
						calculatedDet = calculateDet(readyForCalculateMat, *prevSize);
					}
				}
			#pragma omp section
				{
					if (write > 0)
						fprintf(fpw, "%lf\n", readyForWriteDet);
				}
			}
		}
		readyForCalculateMat = readMat;
		*prevSize = *nextSize;
		readyForWriteDet = calculatedDet;
		write = calc;
		calc = read;
	}
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
	pipeline(fpr, fpw);
	printf("\n");
	fclose(fpr);
	fclose(fpw);
}

void readDirectory(char* dir) {
	WIN32_FIND_DATA FindFileData;
	HANDLE hFind;
	hFind = FindFirstFile(dir, &FindFileData);
	if (hFind == INVALID_HANDLE_VALUE)
	{
		printf("FindFirstFile failed (%d)\n", GetLastError());
		return;
	}
	FindNextFile(hFind, &FindFileData);
	while (FindNextFile(hFind, &FindFileData) != 0) {
		char path[100];
		path[0] = '\0';
		strcat(strcat(path, "./data_in/"), FindFileData.cFileName);
		readFile(path, FindFileData.cFileName);
	}
}

int main() {
	//mkdir("data_out", 0777);
	#ifndef _OPENMP
		printf("omp is not supported!\n");
		system("pause");
	#endif // !_OPENMP
	double start, end;
	start = omp_get_wtime();
	readDirectory("./data_in/*");
	end = omp_get_wtime();
	printf("Time Elapsed: %lfs\n", end - start);
	system("pause");
	return 0;
}
