#ifndef	_PARTICLEFOUNTAIN_H
#define	_PARTICLEFOUNTAIN_H

#include <list>
#include <vector>

#import <OpenGLES/ES1/gl.h>

#include "Vector.h"
typedef Vector<GLfloat, 3>	Vector3f;
typedef	Vector<GLfloat, 4>	RGBAf;

struct Particle
{
    RGBAf	_color;
    RGBAf	_colorRate;
    Vector3f	_position;
    Vector3f	_velocity;
    float	_timeToLive;

    void update(float interval, Vector3f& acceleration)
    {
	_timeToLive -= interval;
	_color += _colorRate*interval;
	_position += _velocity*interval;
	_velocity += acceleration*interval;
    }
};


class ParticleFountain
{
    Vector3f	_acceleration;		// Universal acceleration
    Vector3f	_position;
    Vector3f	_direction;		// Unit vector

    bool	_active;
    float	_diameter;		// Fountain outlet diameter
    float	_lifespan;		// (seconds) Particle lifespan
    unsigned	_rate;			// particles / second
    float	_remainder;		// Fractional particles to create
    float	_speed;			// Characteristic velocity of the particle stream

    RGBAf	_color;			// Initial particle color
    RGBAf	_colorRate;		// Rate of change of particle color

    RGBAf	_colorVariance;
    RGBAf	_colorRateVariance;
    float	_directionVariance;
    float	_lifespanVariance;
    float	_rateVariance;
    float	_speedVariance;

    typedef	std::list<Particle*>	particles_type;
    particles_type	_particles;	// The set of particles in use
    particles_type	_pool;		// Pool of allocated particles

    struct _particle_vertices
    {
	Vector3f	position;
	RGBAf		color;
    };

    std::vector<struct _particle_vertices>   _buffer;

public:
    ParticleFountain() : _active(false), _remainder(0) {}
    ~ParticleFountain()
    {
	particles_type::iterator i = _particles.begin();
	for(; i != _particles.end(); ++i)
	    delete (*i);
	i = _pool.begin();
	for(; i != _particles.end(); ++i)
	    delete (*i);
    }

    void draw();
    void setupView();
    void start()    { _active = true;	}
    void stop()	    { _active = false;	}
    void update(float interval);
    
    void acceleration(Vector3f a)   { _acceleration = a;    }
    void color(RGBAf c)		{ _color = c;	}
    void colorRate(RGBAf r)	{ _colorRate = r;   }
    void diameter(float d)	{ _diameter = d;    }
    void direction(Vector3f d)	{ _direction = d.unit();    }
    void lifespan(float life)	{ _lifespan = life; }
    void position(Vector3f p)	{ _position = p;}
    void rate(unsigned r)	{ _rate = r;	}
    void speed(float s)		{ _speed = s;	}

    void variance(RGBAf c, RGBAf cRV, float dir, float life, float r, float _speed=0)
    {
	_colorVariance = c;
	_colorRateVariance = cRV;
	_directionVariance = dir;
	_lifespanVariance = life;
	_rateVariance = r;
	_speedVariance = _speed;
    }
};

#endif	// _PARTICLEFACTORY_H
