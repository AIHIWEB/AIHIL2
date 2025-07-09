AIHI_package = import_module("github.com/ethpandaops/AIHI-package/main.star")

def run(plan, args):
    # just delegate to AIHI-package
    AIHI_package.run(plan, args)
