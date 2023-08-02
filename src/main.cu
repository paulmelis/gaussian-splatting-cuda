#include "camera.cuh"
#include "camera_utils.cuh"
#include "gaussian.cuh"
#include "loss_utils.cuh"
#include "parameters.cuh"
#include "read_utils.cuh"
#include "scene.cuh"
#include <iostream>
#include <torch/torch.h>

int main(int argc, char* argv[]) {

    if (argc != 2) {
        std::cout << "Usage: ./readPly <ply file>" << std::endl;
        return 1;
    }
    // TODO: read parameters from JSON file or command line
    auto modelParams = ModelParameters();
    modelParams.source_path = argv[1];
    const auto optimParams = OptimizationParameters();
    const auto pipelineParams = PipelineParameters();
    auto gaussians = GaussianModel(modelParams.sh_degree);
    auto scene = Scene(gaussians, modelParams);
    gaussians.Training_setup(optimParams);
    if (!torch::cuda::is_available()) {
        // At the moment, I want to make sure that my GPU is utilized.
        std::cout << "CUDA is not available! Training on CPU." << std::endl;
        exit(-1);
    }
    auto pointType = torch::TensorOptions().dtype(torch::kFloat32);
    const auto bg_color = modelParams.white_background ? torch::tensor({1.f, 1.f, 1.f}) : torch::tensor({0.f, 0.f, 0.f}, pointType).to(torch::kCUDA);

    // training loop
    for (int i = 0; i < optimParams.iterations; ++i) {
        if (i % 1000 == 0) {
            gaussians.One_up_sh_degree();
        }
        // Pick random camera
        // TODO: python code. Tranlate and adapt
        //        if not viewpoint_stack:
        //            viewpoint_stack = scene.getTrainCameras().copy()
        //        viewpoint_cam = viewpoint_stack.pop(randint(0, len(viewpoint_stack)-1))
        //
        // Rendering
        //        render_pkg = render(viewpoint_cam, gaussians, pipe, background)
        //        image, viewspace_point_tensor, visibility_filter, radii = render_pkg["render"], render_pkg["viewspace_points"], render_pkg["visibility_filter"], render_pkg["radii"]
        // Loss Computations
        // TODO: insert real data
        auto t1 = torch::rand({2, 3});
        auto t2 = torch::rand({2, 3});
        auto l1l = gaussian_splatting::l1_loss(t1, t2);
        auto loss = (1.0 - optimParams.lambda_dssim) * l1l + optimParams.lambda_dssim * (1.0 - gaussian_splatting::ssim(t1, t2));
        loss.backward();

        {
            torch::NoGradGuard no_grad;
            // TODO: python code. Tranlate and adapt
            //            # Keep track of max radii in image-space for pruning
            //            gaussians.max_radii2D[visibility_filter] = torch.max(gaussians.max_radii2D[visibility_filter], radii[visibility_filter])
            //
            //            if (iteration in saving_iterations):
            //              print("\n[ITER {}] Saving Gaussians".format(iteration))
            //              scene.save(iteration)
            //
            //            # Densification
            //            if iteration < opt.densify_until_iter:
            //              gaussians.add_densification_stats(viewspace_point_tensor, visibility_filter)
            //
            //            if iteration > opt.densify_from_iter and iteration % opt.densification_interval == 0:
            //              size_threshold = 20 if iteration > opt.opacity_reset_interval else None
            //              gaussians.densify_and_prune(opt.densify_grad_threshold, 0.005, scene.cameras_extent, size_threshold)
            //
            //            if iteration % opt.opacity_reset_interval == 0 or (dataset.white_background and iteration == opt.densify_from_iter):
            //              gaussians.reset_opacity()
            //
            //            # Optimizer step
            //            if iteration < opt.iterations:
            //              gaussians.optimizer.step()
            //              gaussians.optimizer.zero_grad(set_to_none = True)
            //              gaussians.update_learning_rate(iteration)
        }
    }
    return 0;
}