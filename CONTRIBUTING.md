# Contributing

We're glad you're here. Let's make this module even better together.

## Our Approach

This module is opinionated by design. We've made deliberate choices about subnet sizes, tier structure, and defaults based on real-world experience. When contributing, keep that philosophy in mind—we optimize for simplicity and production-readiness.

## Getting Started

```bash
# Clone the repo
git clone https://github.com/vmanikes/terraform-aws-production-vpc.git
cd terraform-aws-production-vpc

# Create a branch
git checkout -b my-feature

# Make your changes
# ...

# Format your code
terraform fmt -recursive

# Validate
terraform validate

# Test with a real plan
terraform plan -var="cidr_block=10.0.0.0/16"
```

## What We're Looking For

✅ **Bug fixes** — Found something broken? We want to know.

✅ **Documentation improvements** — Typos, clarifications, better examples—all welcome.

✅ **Performance improvements** — Faster plans, fewer API calls, smarter logic.

✅ **AWS provider updates** — Help us stay current with new provider versions.

✅ **Security enhancements** — Ideas to make the isolated tier even more secure.

✅ **Better error messages** — Help users understand what went wrong and how to fix it.

## What Probably Won't Fit

This module is intentionally focused. Some changes don't align with our goals:

- **Customizable subnet sizes** — The `/19`, `/20`, `/21` sizing is deliberate. If you have a use case that truly needs different sizes, open an issue first—we'd love to understand the scenario.

- **Optional subnet tiers** — The three-tier model is core to the module's value. If you only need two tiers, a simpler module might be a better fit.

- **Complex variable structures** — We keep inputs flat and simple. Maps of maps add cognitive overhead.

Not sure if your idea fits? Open an issue and let's talk about it.

## Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch from `main`
3. **Make** your changes
4. **Run** `terraform fmt` and `terraform validate`
5. **Test** with `terraform plan` against a real AWS account
6. **Push** and open a PR
7. **Describe** what you changed and why

## Commit Messages

Clear and concise:

```
fix: correct CIDR calculation for isolated subnets
docs: add EKS integration example
feat: support AWS provider 6.x
chore: update terraform version constraint
```

## Code Style

- Run `terraform fmt` before committing
- Use descriptive resource names
- Add comments for non-obvious logic
- Keep `locals` blocks organized and documented
- Match the existing patterns in the codebase

## Questions?

Open an issue. We're happy to help.

---

Thanks for contributing. Every improvement helps the community.
