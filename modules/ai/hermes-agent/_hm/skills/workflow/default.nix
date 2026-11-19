{ inputs, ... }:
{
  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "workflow";
      root = inputs.workflow + "/skills";
      mode = "managed";
    }
  ];
}
