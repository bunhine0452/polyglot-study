struct Rectangle {
    double width;
    double height;

    double area() const {
        if (width <= 0 || height <= 0) {
            return 0.0;
        }
        return width * height;
    }

    double perimeter() const {
        if (width <= 0 || height <= 0) {
            return 0.0;
        }
        return 2 * (width + height);
    }
};
