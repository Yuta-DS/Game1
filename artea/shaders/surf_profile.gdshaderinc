// Low-frequency crest variation shared by the shell, spray and ocean wash.
// Width already varies per event, so each pooled wave gets a stable profile.
float surf_profile_phase(float width) {
	return width*.173;
}

float surf_profile_peel(float u, float age, float width) {
	float phase = surf_profile_phase(width);
	return age + (u-.5)*.24 + .070*sin(u*7.0+phase)
		+ .035*sin(u*17.0+phase*1.7);
}

float surf_profile_bend(float u, float width) {
	float phase = surf_profile_phase(width);
	return .45*sin(u*3.14159265) + .34*sin(u*9.0+phase)
		+ .12*sin(u*19.0+phase*.7);
}
