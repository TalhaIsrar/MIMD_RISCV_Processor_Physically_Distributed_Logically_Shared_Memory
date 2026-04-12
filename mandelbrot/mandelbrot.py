import numpy as np
import matplotlib.pyplot as plt

# Parameters
WIDTH = 160
HEIGHT = 120
FILENAME = 'mandelbrot.txt'

# Read iterations from txt file
def read_mandelbrot(filename):
    with open(filename, 'r') as f:
        # Read entire content
        content = f.read().strip()
        # Split by commas, filter out empty strings
        values = [int(v) for v in content.split(',') if v]
    # Convert to numpy array and reshape
    arr = np.array(values, dtype=np.uint16)
    return arr.reshape((HEIGHT, WIDTH))

# Plot the Mandelbrot set
def plot_mandelbrot(arr):
    plt.figure(figsize=(8,6))
    plt.imshow(arr, cmap='hot', origin='lower')  # origin='lower' ensures correct Y orientation
    plt.colorbar(label='Iterations')
    plt.title("Mandelbrot Set (Q16.16)")
    plt.xlabel("X")
    plt.ylabel("Y")
    plt.show()

if __name__ == "__main__":
    iterations = read_mandelbrot(FILENAME)
    plot_mandelbrot(iterations)