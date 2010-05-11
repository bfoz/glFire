#ifndef	VECTOR_H
#define	VECTOR_H

template<class T, unsigned N>
class Vector
{
    T v[N];

public:
    Vector() : v() {}
};

template<class T>
class Vector<T, 3>
{
    T _x, _y, _z;

public:
    explicit Vector(T value=0)
    {
	_x = _y = _z = value;
    }
    Vector(T x, T y, T z=0)
    {
	_x = x;
	_y = y;
	_z = z;
    }
    Vector(const Vector<T,3>& right)
    {
	_x = right._x;
	_y = right._y;
	_z = right._z;
    }

    T length() const	{ return sqrt(length2()); }
    T length2() const	{ return _x*_x + _y*_y + _z*_z; }
    void normalize()	{ T l = length(); _x /= l; _y /= l; _z /= l;  }
    Vector<T,3> unit() const	{ return *this/length(); }

    T x()   { return _x;    }
    T y()   { return _y;    }
    T z()   { return _z;    }

    Vector<T,3>& operator=(T right)
    {
	_x = right;
	_y = right;
	_z = right;
	return *this;
    }
    
    Vector<T,3>& operator+=(T right)
    {
	_x += right;
	_y += right;
	_z += right;
	return *this;
    }

    Vector<T,3>& operator+=(const Vector<T,3>& right)
    {
	_x += right._x;
	_y += right._y;
	_z += right._z;
	return *this;
    }

    Vector<T,3> operator+(const Vector<T,3>& right)
    {
	return Vector<T,3>(_x+right._x, _y+right._y, _z+right._z);
    }

    Vector<T,3> operator*(T right) const
    {
	return Vector<T,3>(_x*right, _y*right, _z*right);
    }
    Vector<T,3> operator*(const Vector<T,3>& right)
    {
	return Vector<T,3>(_x*right._x, _y*right._y, _z*right._z);
    }
    
    Vector<T,3> operator/(T right) const
    {
	return Vector<T,3>(_x/right, _y/right, _z/right);
    }
};

#endif	// VECTOR_H
