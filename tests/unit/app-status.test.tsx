import { render, screen } from "@testing-library/react";
import Home from "@/app/page";

describe("V1.0 foundation screen", () => {
  it("renders the development status heading", () => {
    render(<Home />);

    expect(
      screen.getByRole("heading", { name: /v1\.0 foundation/i }),
    ).toBeInTheDocument();
  });
});
