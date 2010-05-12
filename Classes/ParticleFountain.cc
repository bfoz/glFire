#include <cmath>

#include "ParticleFountain.h"

// Macro which returns a random value between -1 and 1
#define RANDOM_MINUS_1_TO_1() ((random() / (GLfloat)0x3fffffff )-1.0f)

// Mcro which returns a random number between 0 and 1
#define RANDOM_0_TO_1() ((random() / (GLfloat)0x7fffffff ))

void ParticleFountain::draw()
{
    // Preallocate a vertex buffer
    _buffer.reserve(_particles.size());

    particles_type::iterator i = _particles.begin();
    for(unsigned j=0; i != _particles.end(); ++i, ++j)
    {
	// Copy all active particles into the vertex buffer
	_buffer[j].position = (*i)->_position;
	_buffer[j].color = (*i)->_color;
    }

    glVertexPointer(3, GL_FLOAT, sizeof(_particle_vertices), &(_buffer.front().position));
    glColorPointer(4, GL_FLOAT, sizeof(_particle_vertices), &(_buffer.front().color));
    glDrawArrays(GL_POINTS, 0, _particles.size());
    
}

void ParticleFountain::setupView()
{
    glPointSize(3);
}

// Update all existing particles and then add new particles as needed
void ParticleFountain::update(float interval)
{
    particles_type::iterator i = _particles.begin();
    while(i != _particles.end())
    {
	// Move expiring particles back to the particle pool
	if( (*i)->_timeToLive < interval )
	{
	    _pool.push_back(*i);
	    i = _particles.erase(i);
	    continue;
	}

	(*i)->update(interval, _acceleration);
	++i;
    }

    // New particles are created after updating existing particles to prevent
    //  the new ones from being double-updated upon creation
    if( _active && _rate )
    {
	float numNewParticles = interval * _rate + (_rateVariance * RANDOM_0_TO_1()) + _remainder;
	unsigned num = floor(numNewParticles);
	_remainder = numNewParticles - num; // Save fractional particles for next time
	
	while( num )
	{
	    Particle* p;
	    if( _pool.size() )
	    {
		p = _pool.back();	// Get a particle from the pool
		_pool.pop_back();
	    }
	    else
		p = new Particle;	// Make a new particle
	    _particles.push_back(p);	// Add the particle to the active list
	    --num;

	    // Create a random vector
	    RGBAf c(RANDOM_0_TO_1(), RANDOM_0_TO_1(), RANDOM_0_TO_1(), RANDOM_0_TO_1());
	    Vector3f r(RANDOM_MINUS_1_TO_1(), RANDOM_MINUS_1_TO_1(), RANDOM_MINUS_1_TO_1());

	    // Initialize the new particle
	    p->_color = _color + (c * _colorVariance);
	    p->_colorRate = _colorRate + (c * _colorRateVariance);
	    p->_position = _position + (r.unit() * _diameter);
	    p->_velocity = (_direction + (r * _directionVariance)).unit() * (_speed + _speedVariance);
	    p->_timeToLive = _lifespan + (RANDOM_0_TO_1() * _lifespanVariance);
	}
    }
}
